// Widget test for the `/anuncios` browse-all screen (Sprint 10 Task 4).
//
// Verifies: the grid renders ListingCards for whatever ListingService
// returns, and picking a different sort option from the AppBar dropdown
// re-queries with the newly selected ListingSort. Follows the same
// fake-supabase-with-autoRefreshToken:false pattern as
// promociones_screen_test.dart so no real network call happens and no
// GoTrue auto-refresh timer is left alive across pumpAndSettle.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthClientOptions, SupabaseClient;

import 'package:foxy_ads/core/models/country_model.dart';
import 'package:foxy_ads/core/models/listing_model.dart';
import 'package:foxy_ads/core/providers/selected_country_provider.dart';
import 'package:foxy_ads/core/services/listing_service.dart';
import 'package:foxy_ads/features/home/presentation/widgets/listing_card.dart';
import 'package:foxy_ads/features/listings/presentation/screens/all_listings_screen.dart';
import 'package:foxy_ads/l10n/app_localizations.dart';

final _testCountry = Country(
  code: 'ES',
  name: 'España',
  flag: '🇪🇸',
  currency: 'EUR',
  currencySymbol: '€',
);

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

/// Fake ListingService that ignores Supabase entirely and records the last
/// [ListingSort] it was called with.
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
  final List<ListingSort?> calls = [];

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
    calls.add(sort);
    return _items;
  }
}

class _FakeCountryNotifier extends SelectedCountryNotifier {
  @override
  Country build() => _testCountry;
}

Widget _buildTestApp(FakeListingService service) {
  return ProviderScope(
    overrides: [
      selectedCountryProvider.overrideWith(() => _FakeCountryNotifier()),
      listingServiceProvider.overrideWithValue(service),
    ],
    child: const MaterialApp(
      locale: Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: AllListingsScreen(),
    ),
  );
}

void main() {
  testWidgets('renders a ListingCard per item and defaults to newest sort', (
    tester,
  ) async {
    final service = FakeListingService([
      _listing('l1', 'Anuncio uno'),
      _listing('l2', 'Anuncio dos'),
    ]);

    await tester.pumpWidget(_buildTestApp(service));
    await tester.pumpAndSettle();

    expect(find.byType(ListingCard), findsNWidgets(2));
    expect(service.calls, [ListingSort.newest]);
    expect(find.text('Todos los anuncios'), findsOneWidget);
  });

  testWidgets('picking a sort option re-queries with the new ListingSort', (
    tester,
  ) async {
    final service = FakeListingService([_listing('l1', 'Anuncio uno')]);

    await tester.pumpWidget(_buildTestApp(service));
    await tester.pumpAndSettle();

    // Open the sort popup menu and pick "price low to high".
    await tester.tap(find.byIcon(Icons.sort));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Precio: menor a mayor'));
    await tester.pumpAndSettle();

    expect(service.calls.last, ListingSort.priceLow);
  });
}
