// "Mejorar con IA" description-improve button (Sprint 9 Task B6).
//
// Covers the wiring in `_improveDescription`
// (create_listing_screen.dart): tapping the button sends the current
// description to `ChatService.send` (via `chatServiceProvider`, overridden
// here with a `MockClient`-backed instance so no real network call is
// made) and replaces the description field's text with the returned
// content on success. Also covers the two guard paths: an empty
// description (never calls the chat endpoint) and a failing request
// (description left unchanged).
//
// Mounting pattern mirrors create_listing_geo_test.dart /
// listing_form_mode_test.dart: every provider touched during build is
// overridden so the widget builds synchronously with no platform-channel
// calls.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' show MockClient;
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import 'package:foxy_ads/core/models/category_model.dart';
import 'package:foxy_ads/core/models/country_model.dart';
import 'package:foxy_ads/core/providers/selected_country_provider.dart';
import 'package:foxy_ads/core/services/auth_service.dart';
import 'package:foxy_ads/core/services/listing_service.dart';
import 'package:foxy_ads/features/chat/data/chat_providers.dart';
import 'package:foxy_ads/features/chat/data/chat_service.dart';
import 'package:foxy_ads/features/listings/presentation/screens/create_listing_screen.dart';
import 'package:foxy_ads/l10n/app_localizations.dart';

final _fakeUser = User(
  id: 'test-user-id',
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: '2026-01-01T00:00:00Z',
);

final _fakeCategories = [
  Category(
    id: 'electronics',
    name: 'Electronics',
    nameEs: 'Electrónica',
    icon: '📱',
    color: '#4ECDC4',
    sortOrder: 1,
  ),
];

class _FakeCountryNotifier extends SelectedCountryNotifier {
  @override
  Country build() => Country.defaultCountries.first;
}

Widget _buildTestApp(ChatService chatService) {
  return ProviderScope(
    overrides: [
      authStateProvider.overrideWith((ref) => Stream<User?>.value(_fakeUser)),
      createListingCategoriesProvider.overrideWith(
        (ref) => Future.value(_fakeCategories),
      ),
      categoriesWithSubcategoriesProvider.overrideWith(
        (ref) => Future.value(_fakeCategories),
      ),
      selectedCountryProvider.overrideWith(() => _FakeCountryNotifier()),
      chatServiceProvider.overrideWithValue(chatService),
    ],
    child: MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const CreateListingScreen(),
    ),
  );
}

/// Finds the description `TextFormField` by its label, same lookup pattern
/// as create_listing_geo_test.dart's state-field finder.
Finder _descriptionField(AppLocalizations l10n) => find.ancestor(
      of: find.text(l10n.listingCreateDescriptionLabel),
      matching: find.byType(TextFormField),
    );

void main() {
  testWidgets(
    'tapping "Mejorar con IA" replaces the description with the chat '
    "service's reply and shows the success snackbar",
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      http.Request? captured;
      final chatService = ChatService(
        MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({'content': 'Descripción mejorada por la IA de prueba.'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      await tester.pumpWidget(_buildTestApp(chatService));
      await tester.pumpAndSettle();
      final l10n = await AppLocalizations.delegate.load(const Locale('es'));

      await tester.enterText(
        _descriptionField(l10n),
        'Descripción original corta.',
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('aiImproveButton')));
      // Let the mocked HTTP round trip + the post-await setState settle.
      // (The transient "Mejorando..." loading label is not asserted here: the
      // MockClient resolves on the same microtask the pump drains, so the
      // loading state is inherently racy to observe. The request capture,
      // text replacement, and success snackbar below verify the real
      // behavior.)
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();

      expect(captured, isNotNull);
      final body = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect((body['messages'] as List).last, {
        'role': 'user',
        'content': 'Descripción original corta.',
      });

      expect(
        find.text('Descripción mejorada por la IA de prueba.'),
        findsOneWidget,
      );
      expect(find.text(l10n.aiImproveButton), findsOneWidget);

      // Let the SnackBar's entrance animation finish, then assert it shows
      // the success copy.
      await tester.pump(const Duration(milliseconds: 750));
      expect(find.text(l10n.aiImproveSuccess), findsOneWidget);
    },
  );

  testWidgets(
    'tapping "Mejorar con IA" with an empty description shows the hint '
    'and never calls the chat endpoint',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var callCount = 0;
      final chatService = ChatService(
        MockClient((request) async {
          callCount++;
          return http.Response(jsonEncode({'content': 'unused'}), 200);
        }),
      );

      await tester.pumpWidget(_buildTestApp(chatService));
      await tester.pumpAndSettle();
      final l10n = await AppLocalizations.delegate.load(const Locale('es'));

      await tester.tap(find.byKey(const Key('aiImproveButton')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));

      expect(callCount, 0);
      expect(find.text(l10n.aiImproveEmptyHint), findsOneWidget);
    },
  );

  testWidgets(
    'a failing chat request leaves the description unchanged and shows the '
    'failure snackbar',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final chatService = ChatService(
        MockClient((request) async {
          return http.Response('Internal Server Error', 500);
        }),
      );

      await tester.pumpWidget(_buildTestApp(chatService));
      await tester.pumpAndSettle();
      final l10n = await AppLocalizations.delegate.load(const Locale('es'));

      await tester.enterText(_descriptionField(l10n), 'Texto sin cambios.');
      await tester.pump();

      await tester.tap(find.byKey(const Key('aiImproveButton')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();

      expect(find.text('Texto sin cambios.'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 750));
      expect(find.text(l10n.aiImproveFailed), findsOneWidget);
    },
  );
}
