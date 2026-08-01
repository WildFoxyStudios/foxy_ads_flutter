// Real-estate data models.
//
// T1 scope: define the enums + the *shape* of the filter/facet types
// so downstream tasks (T2 service, T3 form encoder, T4 search screen)
// can wire against them. NO serialization is added here — the
// `toAttributesJson` mapping for the search RPC and the listing
// encoder for the create/edit form are owned by T2 and T3
// respectively.

/// Sort modes accepted by the RE search RPC. The Dart name and the
/// RPC string are intentionally different: the Dart side is the
/// `camelCase` enum case, the RPC side is the snake_case wire value
/// the web's canonical list (RE_SORTS) also uses.
enum ReSort {
  relevance,
  recent,
  priceAsc,
  priceDesc,
  sizeDesc,
  pricePerM2,
}

extension ReSortRpc on ReSort {
  /// Wire value consumed by the search RPC. Matches the entries in
  /// `RE_SORTS` byte-for-byte.
  String toRpcString() {
    switch (this) {
      case ReSort.relevance:
        return 'relevance';
      case ReSort.recent:
        return 'recent';
      case ReSort.priceAsc:
        return 'price_asc';
      case ReSort.priceDesc:
        return 'price_desc';
      case ReSort.sizeDesc:
        return 'size_desc';
      case ReSort.pricePerM2:
        return 'price_m2';
    }
  }
}

/// A single in-flight filter set for the RE search.
///
/// The list-valued fields are intentionally typed as `List<String>`
/// and `List<int>` rather than strongly-typed wrappers because the
/// search RPC takes them as Postgres text[] / int[] and the UI
/// presents them as multi-select chips. Each list is restricted in
/// practice to the values defined in `re_attributes.dart`, but
/// keeping them as `List<String>` lets the same shape carry both
/// "selected" and "available" state without ceremony.
///
/// `cityExact` is `true` for the city-landing route and `false` for
/// fuzzy matching in `/inmuebles-en`.
class ReFilters {
  const ReFilters({
    required this.countryCode,
    this.state,
    this.city,
    this.operation,
    this.propertyTypes = const <String>[],
    this.priceMin,
    this.priceMax,
    this.m2Min,
    this.m2Max,
    this.rooms = const <int>[],
    this.bathrooms = const <int>[],
    this.conditions = const <String>[],
    this.features = const <String>[],
    this.floorBuckets = const <String>[],
    this.energyBands = const <String>[],
    this.orientation = const <String>[],
    this.energyLetter,
    this.petsAllowed,
    this.postedWithinDays,
    this.sort = ReSort.relevance,
    this.cityExact = false,
  });

  final String countryCode;
  final String? state;
  final String? city;
  final String? operation;
  final List<String> propertyTypes;
  final num? priceMin;
  final num? priceMax;
  final num? m2Min;
  final num? m2Max;
  final List<int> rooms;
  final List<int> bathrooms;
  final List<String> conditions;
  final List<String> features;
  final List<String> floorBuckets;
  final List<String> energyBands;
  final List<String> orientation;
  final String? energyLetter;
  final bool? petsAllowed;
  final int? postedWithinDays;
  final ReSort sort;
  final bool cityExact;
}

/// Faceted counts returned alongside a search result page. Keys in
/// each map are members of the corresponding canonical list
/// (RE_PROPERTY_TYPES, RE_CONDITIONS); values are the count of
/// matching listings if that facet were added to the current filter.
class ReFacetCounts {
  const ReFacetCounts({
    this.propertyType = const <String, int>{},
    this.condition = const <String, int>{},
  });

  final Map<String, int> propertyType;
  final Map<String, int> condition;
}
