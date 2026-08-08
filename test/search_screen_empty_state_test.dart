// Widget test for the SearchScreen Sprint-12 fixes:
//   1. Empty /search (no filters set) now falls back to the country's
//      getListings — the user sees a grid, not an "empty state" placeholder.
//   2. /search?q=foo deep-link pre-fills the TextField and runs the search
//      on first frame.
//
// Reuses the FakeListingService pattern from all_listings_screen_test.dart.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthClientOptions, SupabaseClient;

import 'package:foxy_ads/core/models/country_model.dart';
import 'package:foxy_ads/core/models/listing_model.dart';
import 'package:foxy_ads/core/providers/selected_country_provider.dart';
import 'package:foxy_ads/core/services/listing_service.dart';
import 'package:foxy_ads/features/home/presentation/widgets/listing_card.dart';
import 'package:foxy_ads/features/search/presentation/screens/search_screen.dart';
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

  @override
  Future<List<Listing>> searchListings({
    required String query,
    String locale = 'es',
    String? countryCode,
    String? categoryId,
    double? minPrice,
    double? maxPrice,
    String sort = 'newest',
    int limit = 25,
    int offset = 0,
  }) async {
    return _items;
  }
}

class _FakeCountryNotifier extends SelectedCountryNotifier {
  _FakeCountryNotifier(this._initial);
  final Country _initial;
  @override
  Country build() => _initial;
}

Widget _pump(WidgetTester tester, {required List<Listing> items, String? q}) {
  final fakeService = FakeListingService(items);
  final container = ProviderContainer(
    overrides: [
      listingServiceProvider.overrideWithValue(fakeService),
      selectedCountryProvider.overrideWith(
        () => _FakeCountryNotifier(_testCountry),
      ),
    ],
  );
  addTearDown(container.dispose);

  final router = GoRouter(
    initialLocation: q == null ? '/search' : '/search?q=$q',
    routes: [
      GoRoute(
        path: '/search',
        builder: (_, _) => UncontrolledProviderScope(
          container: container,
          child: const SearchScreen(),
        ),
      ),
    ],
  );

  return MaterialApp.router(
    routerConfig: router,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('es'),
  );
}

void main() {
  testWidgets('empty /search renders the country listings (not empty state)',
      (tester) async {
    final items = [_listing('a', 'Item A'), _listing('b', 'Item B')];

    await tester.pumpWidget(_pump(tester, items: items));
    await tester.pumpAndSettle();

    // Listings rendered.
    expect(find.byType(ListingCard), findsNWidgets(2));
    // The SearchScreen's empty-state title is the l10n string
    // `searchEmptyStateTitle`; we never reach it when the fallback returned
    // data. Search for the bottom-of-screen "no listings" emoji (🦊) which
    // only renders in the truly-empty state, and confirm it's absent.
    expect(find.text('🦊'), findsNothing);
  });

  testWidgets('/search?q=iphone pre-fills the TextField and shows results',
      (tester) async {
    final items = [_listing('a', 'iPhone 14')];

    await tester.pumpWidget(_pump(tester, items: items, q: 'iphone'));
    await tester.pumpAndSettle();

    // The TextField should show the deep-linked query text.
    final textField = find.byType(TextField);
    expect(textField, findsOneWidget);
    final widget = tester.widget<TextField>(textField);
    expect(widget.controller!.text, 'iphone');

    // Results rendered (the FTS path falls through to the same FakeService
    // which returns our one item).
    expect(find.byType(ListingCard), findsOneWidget);
  });
}
