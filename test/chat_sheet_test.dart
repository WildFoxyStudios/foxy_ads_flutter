// Widget tests for `ChatSheet` (Sprint 10, Task 2 — Foxy chat UI).
//
// Covers the two user-facing flows the task calls out:
//   1. Typing a message + sending shows the user's message and the
//      assistant's reply in the transcript.
//   2. A `[BUSCAR: term | categoryId]` reply triggers
//      `ListingService.searchListings` and renders the results as
//      `ListingCard`s.
//
// Both `chatServiceProvider` and `listingServiceProvider` are overridden
// with fakes so no network/Supabase call is made.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthClientOptions, SupabaseClient;

import 'package:foxy_ads/core/models/listing_model.dart';
import 'package:foxy_ads/core/services/listing_service.dart';
import 'package:foxy_ads/features/chat/data/chat_models.dart';
import 'package:foxy_ads/features/chat/data/chat_providers.dart';
import 'package:foxy_ads/features/chat/data/chat_service.dart';
import 'package:foxy_ads/features/home/presentation/widgets/listing_card.dart';
import 'package:foxy_ads/features/chat/presentation/widgets/chat_sheet.dart';
import 'package:foxy_ads/l10n/app_localizations.dart';

/// Returns queued canned replies in order, one per `send` call. Records the
/// full conversation handed to each call so the test can assert the user's
/// message reached the service.
class FakeChatService extends ChatService {
  FakeChatService(this.replies);

  final List<String> replies;
  final List<List<ChatMessage>> calls = [];
  int _next = 0;

  @override
  Future<String> send(
    List<ChatMessage> messages, {
    double temperature = 0.7,
    int maxTokens = 200,
  }) async {
    calls.add(messages);
    return replies[_next++];
  }
}

/// Records the args passed to `searchListings` and returns a canned result
/// list, standing in for a real Supabase FTS round-trip.
class FakeListingService extends ListingService {
  FakeListingService(this.results)
      : super(
          SupabaseClient(
            'https://example.supabase.co',
            'public-anon-key',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
          ),
        );

  final List<Listing> results;
  final List<({String query, String? categoryId})> calls = [];

  @override
  Future<List<Listing>> searchListings({
    required String query,
    String locale = 'es',
    String? countryCode,
    String? categoryId,
    double? minPrice,
    double? maxPrice,
    String sort = 'newest',
    int limit = 20,
    int offset = 0,
  }) async {
    calls.add((query: query, categoryId: categoryId));
    return results;
  }
}

Listing _listing(String id, String title) {
  return Listing(
    id: id,
    userId: 'owner-1',
    categoryId: 'vehicles',
    countryCode: 'ES',
    title: title,
    description: 'Test listing',
    price: 12000,
    currency: 'EUR',
    images: const <String>[],
    city: 'Madrid',
    createdAt: DateTime(2026, 1, 1),
  );
}

Widget _buildTestApp({
  required FakeChatService chat,
  required FakeListingService listings,
}) {
  return ProviderScope(
    overrides: [
      chatServiceProvider.overrideWithValue(chat),
      listingServiceProvider.overrideWithValue(listings),
    ],
    child: const MaterialApp(
      locale: Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: ChatSheet()),
    ),
  );
}

Future<void> _sendMessage(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.tap(find.byIcon(Icons.send));
  await tester.pumpAndSettle();
}

void main() {
  group('ChatSheet', () {
    testWidgets(
      'sending a message shows the user text and the assistant reply',
      (tester) async {
        final chat = FakeChatService(['¡Claro! Puedes publicar gratis.']);
        final listings = FakeListingService(const []);

        await tester.pumpWidget(
          _buildTestApp(chat: chat, listings: listings),
        );
        await tester.pumpAndSettle();

        await _sendMessage(tester, '¿cómo publico un anuncio?');

        expect(find.text('¿cómo publico un anuncio?'), findsOneWidget);
        expect(
          find.text('¡Claro! Puedes publicar gratis.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'a [BUSCAR:] reply triggers a listing search and renders ListingCards',
      (tester) async {
        final chat = FakeChatService([
          'Aquí tienes: [BUSCAR: toyota | vehicles]',
        ]);
        final listings = FakeListingService([
          _listing('l1', 'Toyota Corolla 2020'),
          _listing('l2', 'Toyota Yaris 2019'),
        ]);

        await tester.pumpWidget(
          _buildTestApp(chat: chat, listings: listings),
        );
        await tester.pumpAndSettle();

        await _sendMessage(tester, 'busco un toyota');

        expect(
          listings.calls,
          [(query: 'toyota', categoryId: 'vehicles')],
          reason: 'The [BUSCAR: toyota | vehicles] tag should trigger '
              'searchListings(query: "toyota", categoryId: "vehicles")',
        );
        expect(find.byType(ListingCard), findsNWidgets(2));
      },
    );
  });
}
