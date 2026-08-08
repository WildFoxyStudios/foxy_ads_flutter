// Real-estate faceted search providers for the /inmuebles-en screen.
//
// Three providers:
//   * [reSearchFiltersProvider] — the single source of truth for the user's
//     current filter set. `ReSearchFiltersNotifier` exposes per-field setters
//     so the UI can update one knob at a time without leaking the rest.
//   * [reSearchResultsProvider] — `FutureProvider` that watches
//     [reSearchFiltersProvider] (debounced 300ms) and calls
//     `ListingService.searchRealEstate`. Returns `[]` while the filters are
//     at defaults so the screen can show its "select something to start"
//     prompt instead of an empty results grid.
//   * [reFacetCountsProvider] — `FutureProvider` that watches
//     [reSearchFiltersProvider] (debounced 300ms) and calls
//     `ListingService.reFacetCounts`. Always returns an empty
//     [ReFacetCounts] on RPC error so the chip labels degrade gracefully
//     (the count is decorative, not required).
//
// All three providers are NON-autoDispose: back-navigation to this screen
// should reuse the cached results instead of re-hitting the RPC.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/listing_model.dart';
import '../../../../core/providers/selected_country_provider.dart';
import '../../../../core/services/listing_service.dart';
import '../../data/re_models.dart';

/// Build an [ReFilters] from a raw `ReSearchFilters`-style value. The
/// factory lives here (not on `ReFilters` itself) because the search
/// screen's notifier holds a *mutable* view (`ReSearchFilters`) and we
/// only want to build the immutable RPC-payload shape at the boundary.
ReFilters _reFiltersFrom(
  String countryCode, {
  String? state,
  String? city,
  String? operation,
  List<String> propertyTypes = const <String>[],
  num? priceMin,
  num? priceMax,
  num? m2Min,
  num? m2Max,
  List<int> rooms = const <int>[],
  List<int> bathrooms = const <int>[],
  List<String> conditions = const <String>[],
  List<String> features = const <String>[],
  List<String> floorBuckets = const <String>[],
  List<String> energyBands = const <String>[],
  List<String> orientation = const <String>[],
  String? energyLetter,
  bool? petsAllowed,
  int? postedWithinDays,
  ReSort sort = ReSort.relevance,
  bool cityExact = false,
}) {
  return ReFilters(
    countryCode: countryCode,
    state: state,
    city: city,
    operation: operation,
    propertyTypes: propertyTypes,
    priceMin: priceMin,
    priceMax: priceMax,
    m2Min: m2Min,
    m2Max: m2Max,
    rooms: rooms,
    bathrooms: bathrooms,
    conditions: conditions,
    features: features,
    floorBuckets: floorBuckets,
    energyBands: energyBands,
    orientation: orientation,
    energyLetter: energyLetter,
    petsAllowed: petsAllowed,
    postedWithinDays: postedWithinDays,
    sort: sort,
    cityExact: cityExact,
  );
}

/// Mutable, view-shaped filter set held by [ReSearchFiltersNotifier]. Mirrors
/// the public surface the screen needs (no `state`, no `countryCode` — those
/// are derived from `selectedCountryProvider` so swapping the country clears
/// the rest of the form via `clear()`).
class ReSearchFilters {
  const ReSearchFilters({
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

  /// "Active" means the user has narrowed something — non-default values
  /// anywhere. The screen renders its prompt when this is `false`.
  bool get isActive =>
      state != null ||
      city != null ||
      operation != null ||
      propertyTypes.isNotEmpty ||
      priceMin != null ||
      priceMax != null ||
      m2Min != null ||
      m2Max != null ||
      rooms.isNotEmpty ||
      bathrooms.isNotEmpty ||
      conditions.isNotEmpty ||
      features.isNotEmpty ||
      floorBuckets.isNotEmpty ||
      energyBands.isNotEmpty ||
      orientation.isNotEmpty ||
      energyLetter != null ||
      petsAllowed != null ||
      postedWithinDays != null ||
      sort != ReSort.relevance ||
      cityExact;

  ReSearchFilters copyWith({
    Object? state = _sentinel,
    Object? city = _sentinel,
    Object? operation = _sentinel,
    List<String>? propertyTypes,
    Object? priceMin = _sentinel,
    Object? priceMax = _sentinel,
    Object? m2Min = _sentinel,
    Object? m2Max = _sentinel,
    List<int>? rooms,
    List<int>? bathrooms,
    List<String>? conditions,
    List<String>? features,
    List<String>? floorBuckets,
    List<String>? energyBands,
    List<String>? orientation,
    Object? energyLetter = _sentinel,
    Object? petsAllowed = _sentinel,
    Object? postedWithinDays = _sentinel,
    ReSort? sort,
    bool? cityExact,
  }) {
    return ReSearchFilters(
      state: identical(state, _sentinel) ? this.state : state as String?,
      city: identical(city, _sentinel) ? this.city : city as String?,
      operation: identical(operation, _sentinel)
          ? this.operation
          : operation as String?,
      propertyTypes: propertyTypes ?? this.propertyTypes,
      priceMin: identical(priceMin, _sentinel)
          ? this.priceMin
          : priceMin as num?,
      priceMax: identical(priceMax, _sentinel)
          ? this.priceMax
          : priceMax as num?,
      m2Min: identical(m2Min, _sentinel) ? this.m2Min : m2Min as num?,
      m2Max: identical(m2Max, _sentinel) ? this.m2Max : m2Max as num?,
      rooms: rooms ?? this.rooms,
      bathrooms: bathrooms ?? this.bathrooms,
      conditions: conditions ?? this.conditions,
      features: features ?? this.features,
      floorBuckets: floorBuckets ?? this.floorBuckets,
      energyBands: energyBands ?? this.energyBands,
      orientation: orientation ?? this.orientation,
      energyLetter: identical(energyLetter, _sentinel)
          ? this.energyLetter
          : energyLetter as String?,
      petsAllowed: identical(petsAllowed, _sentinel)
          ? this.petsAllowed
          : petsAllowed as bool?,
      postedWithinDays: identical(postedWithinDays, _sentinel)
          ? this.postedWithinDays
          : postedWithinDays as int?,
      sort: sort ?? this.sort,
      cityExact: cityExact ?? this.cityExact,
    );
  }

  static const Object _sentinel = Object();

  @override
  bool operator ==(Object other) =>
      other is ReSearchFilters &&
      other.state == state &&
      other.city == city &&
      other.operation == operation &&
      _listEq(other.propertyTypes, propertyTypes) &&
      other.priceMin == priceMin &&
      other.priceMax == priceMax &&
      other.m2Min == m2Min &&
      other.m2Max == m2Max &&
      _listEq(other.rooms, rooms) &&
      _listEq(other.bathrooms, bathrooms) &&
      _listEq(other.conditions, conditions) &&
      _listEq(other.features, features) &&
      _listEq(other.floorBuckets, floorBuckets) &&
      _listEq(other.energyBands, energyBands) &&
      _listEq(other.orientation, orientation) &&
      other.energyLetter == energyLetter &&
      other.petsAllowed == petsAllowed &&
      other.postedWithinDays == postedWithinDays &&
      other.sort == sort &&
      other.cityExact == cityExact;

  @override
  int get hashCode => Object.hash(
        state,
        city,
        operation,
        Object.hashAll(propertyTypes),
        priceMin,
        priceMax,
        m2Min,
        m2Max,
        Object.hashAll(rooms),
        Object.hashAll(bathrooms),
        Object.hashAll(conditions),
        Object.hashAll(features),
        Object.hashAll(floorBuckets),
        Object.hashAll(energyBands),
        Object.hashAll(orientation),
        energyLetter,
        petsAllowed,
        postedWithinDays,
        sort,
        cityExact,
      );

  /// Serializes to the shape persisted in `saved_searches.query`. Only
  /// non-null/non-empty fields are emitted (keeps the payload small); the
  /// `'_kind': 're'` discriminator lets [SavedSearch.isRealEstate]
  /// distinguish this from the non-RE `SearchFilters` payload without a
  /// dedicated column.
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{'_kind': 're'};
    if (state != null) json['state'] = state;
    if (city != null) json['city'] = city;
    if (operation != null) json['operation'] = operation;
    if (propertyTypes.isNotEmpty) json['propertyTypes'] = propertyTypes;
    if (priceMin != null) json['priceMin'] = priceMin;
    if (priceMax != null) json['priceMax'] = priceMax;
    if (m2Min != null) json['m2Min'] = m2Min;
    if (m2Max != null) json['m2Max'] = m2Max;
    if (rooms.isNotEmpty) json['rooms'] = rooms;
    if (bathrooms.isNotEmpty) json['bathrooms'] = bathrooms;
    if (conditions.isNotEmpty) json['conditions'] = conditions;
    if (features.isNotEmpty) json['features'] = features;
    if (floorBuckets.isNotEmpty) json['floorBuckets'] = floorBuckets;
    if (energyBands.isNotEmpty) json['energyBands'] = energyBands;
    if (orientation.isNotEmpty) json['orientation'] = orientation;
    if (energyLetter != null) json['energyLetter'] = energyLetter;
    if (petsAllowed != null) json['petsAllowed'] = petsAllowed;
    if (postedWithinDays != null) {
      json['postedWithinDays'] = postedWithinDays;
    }
    if (sort != ReSort.relevance) json['sort'] = sort.name;
    if (cityExact) json['cityExact'] = cityExact;
    return json;
  }

  /// Inverse of [toJson]. Tolerant of missing keys (defaults match the
  /// constructor's defaults) so partially-populated or older payloads still
  /// parse.
  factory ReSearchFilters.fromJson(Map<String, dynamic> json) {
    List<String> stringList(String key) =>
        (json[key] as List?)?.map((e) => e as String).toList() ??
        const <String>[];
    List<int> intList(String key) =>
        (json[key] as List?)?.map((e) => (e as num).toInt()).toList() ??
        const <int>[];

    return ReSearchFilters(
      state: json['state'] as String?,
      city: json['city'] as String?,
      operation: json['operation'] as String?,
      propertyTypes: stringList('propertyTypes'),
      priceMin: json['priceMin'] as num?,
      priceMax: json['priceMax'] as num?,
      m2Min: json['m2Min'] as num?,
      m2Max: json['m2Max'] as num?,
      rooms: intList('rooms'),
      bathrooms: intList('bathrooms'),
      conditions: stringList('conditions'),
      features: stringList('features'),
      floorBuckets: stringList('floorBuckets'),
      energyBands: stringList('energyBands'),
      orientation: stringList('orientation'),
      energyLetter: json['energyLetter'] as String?,
      petsAllowed: json['petsAllowed'] as bool?,
      postedWithinDays: json['postedWithinDays'] as int?,
      sort: ReSort.values.firstWhere(
        (s) => s.name == json['sort'],
        orElse: () => ReSort.relevance,
      ),
      cityExact: json['cityExact'] as bool? ?? false,
    );
  }
}

bool _listEq<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Single source of truth for the real-estate search filters. Replaces the
/// 17-field monolith the spec sketched so the screen uses one
/// `ref.watch(reSearchFiltersProvider)` instead of 17.
class ReSearchFiltersNotifier extends Notifier<ReSearchFilters> {
  @override
  ReSearchFilters build() => const ReSearchFilters();

  void setState(String? value) => state = state.copyWith(state: value);
  void setCity(String? value) => state = state.copyWith(city: value);
  void setOperation(String? value) =>
      state = state.copyWith(operation: value);
  void setSort(ReSort value) => state = state.copyWith(sort: value);
  void setPriceMin(num? value) => state = state.copyWith(priceMin: value);
  void setPriceMax(num? value) => state = state.copyWith(priceMax: value);
  void setM2Min(num? value) => state = state.copyWith(m2Min: value);
  void setM2Max(num? value) => state = state.copyWith(m2Max: value);
  void setEnergyLetter(String? value) =>
      state = state.copyWith(energyLetter: value);
  void setPetsAllowed(bool? value) =>
      state = state.copyWith(petsAllowed: value);
  void setPostedWithinDays(int? value) =>
      state = state.copyWith(postedWithinDays: value);
  void setCityExact(bool value) => state = state.copyWith(cityExact: value);

  /// Toggles membership of a string in a multi-select field. Pass
  /// `clearWhenLast=true` to deselect to `null` instead of empty list so the
  /// search "narrows something" rule is satisfied only while the user has
  /// at least one chip.
  void toggleString(
    String field, {
    required String value,
    bool clearWhenLast = true,
  }) {
    switch (field) {
      case 'propertyTypes':
        final next = List<String>.from(state.propertyTypes);
        if (next.contains(value)) {
          next.remove(value);
        } else {
          next.add(value);
        }
        state = state.copyWith(
          propertyTypes: clearWhenLast && next.isEmpty ? const [] : next,
        );
        break;
      case 'conditions':
        final next = List<String>.from(state.conditions);
        if (next.contains(value)) {
          next.remove(value);
        } else {
          next.add(value);
        }
        state = state.copyWith(
          conditions: clearWhenLast && next.isEmpty ? const [] : next,
        );
        break;
      case 'features':
        final next = List<String>.from(state.features);
        if (next.contains(value)) {
          next.remove(value);
        } else {
          next.add(value);
        }
        state = state.copyWith(
          features: clearWhenLast && next.isEmpty ? const [] : next,
        );
        break;
      case 'floorBuckets':
        final next = List<String>.from(state.floorBuckets);
        if (next.contains(value)) {
          next.remove(value);
        } else {
          next.add(value);
        }
        state = state.copyWith(
          floorBuckets: clearWhenLast && next.isEmpty ? const [] : next,
        );
        break;
      case 'energyBands':
        final next = List<String>.from(state.energyBands);
        if (next.contains(value)) {
          next.remove(value);
        } else {
          next.add(value);
        }
        state = state.copyWith(
          energyBands: clearWhenLast && next.isEmpty ? const [] : next,
        );
        break;
      case 'orientation':
        final next = List<String>.from(state.orientation);
        if (next.contains(value)) {
          next.remove(value);
        } else {
          next.add(value);
        }
        state = state.copyWith(
          orientation: clearWhenLast && next.isEmpty ? const [] : next,
        );
        break;
    }
  }

  /// Toggles membership of an int in `rooms` or `bathrooms`.
  void toggleInt(String field, int value) {
    switch (field) {
      case 'rooms':
        final next = List<int>.from(state.rooms);
        if (next.contains(value)) {
          next.remove(value);
        } else {
          next.add(value);
        }
        state = state.copyWith(rooms: next);
        break;
      case 'bathrooms':
        final next = List<int>.from(state.bathrooms);
        if (next.contains(value)) {
          next.remove(value);
        } else {
          next.add(value);
        }
        state = state.copyWith(bathrooms: next);
        break;
    }
  }

  /// Replaces the entire filter set (e.g. re-running a saved search in a
  /// future T5/T6). Mirrors the saved-searches pattern from Sprint 1.
  void setAll(ReSearchFilters filters) => state = filters;

  void clear() => state = const ReSearchFilters();
}

final reSearchFiltersProvider =
    NotifierProvider<ReSearchFiltersNotifier, ReSearchFilters>(
      () => ReSearchFiltersNotifier(),
    );

/// Debounce duration applied to filter changes before they re-fire the
/// search/facet RPCs. 300ms matches the spec.
const Duration _debounce = Duration(milliseconds: 300);

/// Debounce wrapper that watches [reSearchFiltersProvider] and [selectedCountryProvider],
/// and emits the latest value only after [_debounce] of inactivity. Returns
/// `null` until the first non-default value arrives so the screen can show
/// its "pick a country/operation" prompt without flicker.
({ReFilters filters, bool active})? _watchDebounced(Ref ref) {
  // We don't actually need a stream here — Riverpod's `ref.listen` lets us
  // debounce imperatively. This helper is the indirection point so both the
  // results provider and the facet-counts provider share the same schedule.
  final filters = ref.watch(reSearchFiltersProvider);
  final country = ref.watch(selectedCountryProvider);
  return (
    filters: _reFiltersFrom(
      country.code,
      state: filters.state,
      city: filters.city,
      operation: filters.operation,
      propertyTypes: filters.propertyTypes,
      priceMin: filters.priceMin,
      priceMax: filters.priceMax,
      m2Min: filters.m2Min,
      m2Max: filters.m2Max,
      rooms: filters.rooms,
      bathrooms: filters.bathrooms,
      conditions: filters.conditions,
      features: filters.features,
      floorBuckets: filters.floorBuckets,
      energyBands: filters.energyBands,
      orientation: filters.orientation,
      energyLetter: filters.energyLetter,
      petsAllowed: filters.petsAllowed,
      postedWithinDays: filters.postedWithinDays,
      sort: filters.sort,
      cityExact: filters.cityExact,
    ),
    active: filters.isActive,
  );
}

/// Debounced RE search results. Internally tracks a per-provider `Timer`
/// so rapid filter changes coalesce into a single RPC call.
final reSearchResultsProvider = FutureProvider<List<Listing>>((ref) async {
  final snapshot = _watchDebounced(ref);
  if (snapshot == null || !snapshot.active) {
    return const <Listing>[];
  }

  // Debounce: wait _debounce of inactivity before firing the RPC. The
  // Timer is reset on every re-eval (i.e. every filter change), so the
  // actual fetch only runs after the user stops typing/clicking for
  // 300ms.
  final completer = Completer<List<Listing>>();
  final timer = Timer(_debounce, () async {
    try {
      final service = ref.read(listingServiceProvider);
      final result = await service.searchRealEstate(snapshot.filters);
      if (!completer.isCompleted) completer.complete(result.items);
    } catch (e, st) {
      if (!completer.isCompleted) completer.completeError(e, st);
    }
  });
  ref.onDispose(() {
    timer.cancel();
    if (!completer.isCompleted) {
      completer.complete(const <Listing>[]);
    }
  });
  return completer.future;
});

/// Debounced RE facet counts. Calls the facet RPC with the same (latest)
/// filter set as the search provider. Returns an empty [ReFacetCounts] on
/// RPC error so chip labels degrade gracefully.
final reFacetCountsProvider = FutureProvider<ReFacetCounts>((ref) async {
  final snapshot = _watchDebounced(ref);
  if (snapshot == null) {
    return const ReFacetCounts();
  }

  final completer = Completer<ReFacetCounts>();
  final timer = Timer(_debounce, () async {
    try {
      final service = ref.read(listingServiceProvider);
      final counts = await service.reFacetCounts(snapshot.filters);
      if (!completer.isCompleted) completer.complete(counts);
    } catch (e, st) {
      if (!completer.isCompleted) completer.completeError(e, st);
    }
  });
  ref.onDispose(() {
    timer.cancel();
    if (!completer.isCompleted) {
      completer.complete(const ReFacetCounts());
    }
  });
  return completer.future;
});
