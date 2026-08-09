import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:foxy_ads/core/models/listing_model.dart';
import 'package:foxy_ads/core/models/saved_search_model.dart';
import 'package:foxy_ads/core/providers/selected_country_provider.dart';
import 'package:foxy_ads/core/services/listing_service.dart';
import 'package:foxy_ads/core/services/saved_searches_service.dart';
import 'package:foxy_ads/features/real-estate/presentation/providers/re_search_provider.dart';

export 'package:foxy_ads/core/services/saved_searches_service.dart'
    show savedSearchesServiceProvider;

/// The current user's saved searches, newest first.
final savedSearchesProvider = FutureProvider<List<SavedSearch>>((ref) async {
  final service = ref.watch(savedSearchesServiceProvider);
  return service.list();
});

/// New-match count for a single saved search (Plan 10 N2): how many listings
/// matching the saved filter were created AFTER the search was last seen
/// (`lastSeenAt`, or `createdAt` for a never-opened search).
///
/// Reuses the EXACT live-search path so the filter shape is correct: RE
/// searches go through `searchRealEstate` with [reFiltersFromSaved]; regular
/// searches use `getListings` with the saved category/price/country (the
/// free-text `q` dimension is not re-applied — saved searches are dominated
/// by category/price filters, and the count is a capped badge signal, so an
/// approximation on the first page of results is acceptable). Counting is
/// client-side over the returned page; any error resolves to 0 (a badge must
/// never surface an error).
final savedSearchNewCountProvider =
    FutureProvider.family<int, String>((ref, savedSearchId) async {
  final searches = await ref.watch(savedSearchesProvider.future);
  SavedSearch? search;
  for (final s in searches) {
    if (s.id == savedSearchId) {
      search = s;
      break;
    }
  }
  if (search == null) return 0;

  final since = search.lastSeenAt ?? search.createdAt;
  final service = ref.read(listingServiceProvider);
  final countryCode =
      search.countryCode ?? ref.read(selectedCountryProvider).code;

  try {
    List<Listing> items;
    if (search.isRealEstate) {
      final filters =
          reFiltersFromSaved(ReSearchFilters.fromJson(search.rawQuery), countryCode);
      final result = await service.searchRealEstate(filters, limit: 50);
      items = result.items;
    } else {
      final f = search.filters;
      items = await service.getListings(
        countryCode: countryCode,
        categoryId: f.categoryId,
        minPrice: f.minPrice,
        maxPrice: f.maxPrice,
        limit: 50,
      );
    }
    return items.where((l) => l.createdAt.isAfter(since)).length;
  } catch (_) {
    return 0;
  }
});

/// Total new matches across all saved searches — the profile/bell badge.
final savedSearchTotalNewProvider = FutureProvider<int>((ref) async {
  final searches = await ref.watch(savedSearchesProvider.future);
  var total = 0;
  for (final s in searches) {
    total += await ref.watch(savedSearchNewCountProvider(s.id).future);
  }
  return total;
});
