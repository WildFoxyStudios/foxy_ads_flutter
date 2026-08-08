// Widget tests for `RelatedListingsRail` (P9 Task A5) — the horizontal
// "related listings" rail at the bottom of the listing-detail screen.
//
// Follows the FakeListingService pattern from all_listings_screen_test.dart:
// a fake service (backed by a throwaway SupabaseClient with
// autoRefreshToken: false so no real network/timer touches the test) returns
// a fixed list of listings regardless of the query args.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthClientOptions, SupabaseClient;

import 'package:foxy_ads/core/models/listing_model.dart';
import 'package:foxy_ads/core/services/auth_service.dart';
import 'package:foxy_ads/core/services/favorite_service.dart';
import 'package:foxy_ads/core/services/listing_service.dart';
import 'package:foxy_ads/features/home/presentation/widgets/listing_card.dart';
import 'package:foxy_ads/features/listings/presentation/widgets/related_listings_rail.dart';
import 'package:foxy_ads/l10n/app_localizations.dart';

Listing _listing(String id, String title) {
  return Listing(
    id: id,
    userId: 'user-1',
    categoryId: 'vehicles',
    countryCode: 'ES',
    title: title,
    description: 'desc',
    price: 100,
    images: const [],
    createdAt: DateTime(2026, 1, 1),
  );
}

/// Fake ListingService that ignores Supabase entirely and always returns the
/// fixed [_items] list regardless of the filter args passed to `getListings`.
class FakeListingService extends ListingService {
  FakeListingService(this._items)
      : super(
          SupabaseClient(
            'https://example.supabase.co',
            'public-anon-key',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
          ),
        );

  final List<Listing> _items;

  @override
  Future<List<Listing>> getListings({
    String? countryCode,
    String? categoryId,
    String? subcategoryId,
    String? searchQuery,
    double? minPrice,
    double? maxPrice,
    String? city,
    bool featuredFirst = true,
    ListingSort? sort,
    int limit = 20,
    int offset = 0,
  }) async {
    return _items;
  }
}

Widget _buildTestApp(FakeListingService service, Listing current) {
  return ProviderScope(
    overrides: [
      listingServiceProvider.overrideWithValue(service),
      authStateProvider.overrideWith((ref) => Stream.value(null)),
      userFavoritesProvider.overrideWith((ref) async => <String>[]),
    ],
    child: MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: RelatedListingsRail(listing: current),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'renders the heading and excludes the current listing from the rail',
    (tester) async {
      final current = _listing('l1', 'Anuncio actual');
      final service = FakeListingService([
        current,
        _listing('l2', 'Anuncio dos'),
        _listing('l3', 'Anuncio tres'),
      ]);

      await tester.pumpWidget(_buildTestApp(service, current));
      await tester.pumpAndSettle();

      expect(find.text('También te puede interesar'), findsOneWidget);
      // 3 fetched, but the current listing (l1) is excluded -> 2 cards.
      expect(find.byType(ListingCard), findsNWidgets(2));
      expect(find.text('Anuncio actual'), findsNothing);
      expect(find.text('Anuncio dos'), findsOneWidget);
      expect(find.text('Anuncio tres'), findsOneWidget);
    },
  );

  testWidgets(
    'renders nothing when the only result is the current listing',
    (tester) async {
      final current = _listing('l1', 'Anuncio actual');
      final service = FakeListingService([current]);

      await tester.pumpWidget(_buildTestApp(service, current));
      await tester.pumpAndSettle();

      expect(find.text('También te puede interesar'), findsNothing);
      expect(find.byType(ListingCard), findsNothing);
      expect(find.byType(SizedBox), findsWidgets);
    },
  );
}
