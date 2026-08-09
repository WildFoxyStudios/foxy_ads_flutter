// savedSearchNewCountProvider (Plan 10 N2): counts listings matching a saved
// (non-RE) search created after its lastSeenAt. Uses a fake ListingService so
// no Supabase round-trip happens.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthClientOptions, SupabaseClient;

import 'package:foxy_ads/core/models/country_model.dart';
import 'package:foxy_ads/core/models/listing_model.dart';
import 'package:foxy_ads/core/models/saved_search_model.dart';
import 'package:foxy_ads/core/providers/selected_country_provider.dart';
import 'package:foxy_ads/core/services/listing_service.dart';
import 'package:foxy_ads/features/search/presentation/providers/saved_searches_provider.dart';
import 'package:foxy_ads/features/search/presentation/providers/search_filters_provider.dart';

Listing _listing(String id, DateTime createdAt) => Listing(
      id: id,
      userId: 'u1',
      categoryId: 'vehicles',
      countryCode: 'ES',
      title: id,
      description: 'd',
      price: 100,
      images: const [],
      createdAt: createdAt,
    );

class _FakeListingService extends ListingService {
  _FakeListingService(this._items)
      : super(
          SupabaseClient(
            'https://example.supabase.co',
            'anon',
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
  }) async =>
      _items;
}

class _FakeCountryNotifier extends SelectedCountryNotifier {
  @override
  Country build() => Country.defaultCountries.first;
}

SavedSearch _saved({required DateTime lastSeen}) => SavedSearch(
      id: 's1',
      userId: 'u1',
      categoryId: 'vehicles',
      filters: const SearchFilters(categoryId: 'vehicles'),
      rawQuery: const {'categoryId': 'vehicles'},
      countryCode: 'ES',
      createdAt: DateTime(2026, 1, 1),
      lastSeenAt: lastSeen,
    );

void main() {
  test('counts only listings created after lastSeenAt', () async {
    final lastSeen = DateTime(2026, 8, 1);
    final items = [
      _listing('old', DateTime(2026, 7, 20)), // before → not counted
      _listing('new1', DateTime(2026, 8, 3)), // after → counted
      _listing('new2', DateTime(2026, 8, 5)), // after → counted
    ];

    final container = ProviderContainer(
      overrides: [
        listingServiceProvider.overrideWithValue(_FakeListingService(items)),
        selectedCountryProvider.overrideWith(() => _FakeCountryNotifier()),
        savedSearchesProvider.overrideWith((ref) async => [_saved(lastSeen: lastSeen)]),
      ],
    );
    addTearDown(container.dispose);

    final count =
        await container.read(savedSearchNewCountProvider('s1').future);
    expect(count, 2);
  });

  test('returns 0 for an unknown saved-search id', () async {
    final container = ProviderContainer(
      overrides: [
        listingServiceProvider.overrideWithValue(_FakeListingService(const [])),
        selectedCountryProvider.overrideWith(() => _FakeCountryNotifier()),
        savedSearchesProvider.overrideWith((ref) async => const <SavedSearch>[]),
      ],
    );
    addTearDown(container.dispose);

    final count =
        await container.read(savedSearchNewCountProvider('missing').future);
    expect(count, 0);
  });
}
