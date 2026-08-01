import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foxy_ads/core/models/listing_model.dart';
import 'package:foxy_ads/core/providers/selected_country_provider.dart';
import 'package:foxy_ads/core/services/listing_service.dart';

/// Immutable snapshot of all search filters. Held by [SearchFiltersNotifier].
class SearchFilters {
  const SearchFilters({
    this.query = '',
    this.categoryId,
    this.minPrice,
    this.maxPrice,
    this.sort = 'newest',
  });

  final String query;
  final String? categoryId;
  final double? minPrice;
  final double? maxPrice;
  /// RPC `search_listings` accepts 'newest' | 'oldest' | 'price_asc' |
  /// 'price_desc'. Defaults to 'newest'.
  final String sort;

  /// Filters are considered "active" (non-empty) if the user has typed a query
  /// OR narrowed down to a category OR specified a price range OR changed the
  /// sort from the default.
  bool get isActive =>
      query.isNotEmpty ||
      categoryId != null ||
      minPrice != null ||
      maxPrice != null ||
      sort != 'newest';

  SearchFilters copyWith({
    String? query,
    Object? categoryId = _sentinel,
    Object? minPrice = _sentinel,
    Object? maxPrice = _sentinel,
    String? sort,
  }) {
    return SearchFilters(
      query: query ?? this.query,
      categoryId: identical(categoryId, _sentinel)
          ? this.categoryId
          : categoryId as String?,
      minPrice: identical(minPrice, _sentinel)
          ? this.minPrice
          : minPrice as double?,
      maxPrice: identical(maxPrice, _sentinel)
          ? this.maxPrice
          : maxPrice as double?,
      sort: sort ?? this.sort,
    );
  }

  static const Object _sentinel = Object();

  @override
  bool operator ==(Object other) =>
      other is SearchFilters &&
      other.query == query &&
      other.categoryId == categoryId &&
      other.minPrice == minPrice &&
      other.maxPrice == maxPrice &&
      other.sort == sort;

  @override
  int get hashCode => Object.hash(query, categoryId, minPrice, maxPrice, sort);
}

/// Single source of truth for search filter state. Replaces four separate
/// NotifierProviders (query / category / minPrice / maxPrice) so that:
///   1. The screen only `ref.watch`es one provider for all filter state.
///   2. The screen uses [SearchFiltersNotifier.update] to mutate one field at a
///      time without leaking the 4 separate `notifier.update(...)` calls.
///   3. Tests can override [searchResultsProvider] (below) by passing a
///      canned `SearchFilters` state.
class SearchFiltersNotifier extends Notifier<SearchFilters> {
  @override
  SearchFilters build() => const SearchFilters();

  void setQuery(String value) => state = state.copyWith(query: value);
  void setCategory(String? value) =>
      state = state.copyWith(categoryId: value);
  void setMinPrice(double? value) =>
      state = state.copyWith(minPrice: value);
  void setMaxPrice(double? value) =>
      state = state.copyWith(maxPrice: value);
  void setSort(String value) => state = state.copyWith(sort: value);

  void clear() => state = const SearchFilters();
}

final searchFiltersProvider =
    NotifierProvider<SearchFiltersNotifier, SearchFilters>(
      () => SearchFiltersNotifier(),
    );

/// Derived: re-runs whenever any field in [searchFiltersProvider] changes
/// (or the selected country). Returns an empty list when no filters are active
/// so the UI can show the empty-state placeholder.
final searchResultsProvider = FutureProvider<List<Listing>>((ref) async {
  final filters = ref.watch(searchFiltersProvider);
  final country = ref.watch(selectedCountryProvider);
  final listingService = ref.read(listingServiceProvider);

  if (!filters.isActive) {
    return [];
  }

  // Use the FTS RPC: locale-aware tsvector ranking, supports ES/EN/IT
  // accents, uses the GIN index on `listings.search_vector`. The RPC also
  // returns a `headline` field with highlighted matches (not surfaced to the
  // list card yet — it lives on the detail screen's search result path).
  //
  // All Hispanophone countries (ES/MX/AR/...) — fixed 'es' locale for the
  // tsvector configuration. When the app gains EN/IT support, pull this from
  // `country.locale` (or a future user-locale preference provider).
  return await listingService.searchListings(
    query: filters.query,
    locale: 'es',
    countryCode: country.code,
    categoryId: filters.categoryId,
    minPrice: filters.minPrice,
    maxPrice: filters.maxPrice,
    sort: filters.sort,
    limit: 50,
  );
});