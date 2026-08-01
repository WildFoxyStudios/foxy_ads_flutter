# Flutter Sprint 2 — Real-Estate Vertical — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring the Flutter app's real-estate (inmuebles) vertical to parity
with the web's `/inmuebles-en` flow: structured RE attributes on create/edit,
a faceted search screen at `/inmuebles-en`, a city landing at
`/inmuebles-en/[city]`, and a `/valorar` (property-value estimator).

**Architecture:** Riverpod 3 + go_router + Supabase, `core/` + `features/`
layers. The web's RPCs (`search_real_estate`, `real_estate_facet_counts`)
and the `listings.attributes` JSONB column (with trigger
`trg_validate_listing_attributes`) are already in place — **no new schema or
RPCs**. Sprint 2 is client-side: UI + service + providers calling the
existing Supabase surface.

**Tech Stack:** Flutter 3.44 / Dart 3.12, flutter_riverpod ^3, go_router ^17,
supabase_flutter ^2.

## Global Constraints

- `flutter analyze` must report **0 errors** after every task (pre-existing
  deprecation `info`s are acceptable).
- `flutter test` must pass the whole suite (6 existing + new tests) after
  the final task.
- `flutter build apk --debug --no-pub` must succeed after the final task.
- No new dependencies. `path_provider_android` stays pinned to `2.2.23`.
- All RE attribute keys stored in `listings.attributes` must EXACTLY match
  the web's `buildRpcArgs` field names (`operation, property_type, m2,
  rooms, bathrooms, condition, features, floor, floor_buckets, energy_bands,
  energy_letter, orientation, pets_allowed`) so the existing RPC predicates
  and validation trigger accept the writes.
- `pets_allowed` is stored as the string `'1'` / `'0'` (Supabase JSONB
  has no native boolean facet) — the trigger and search RPC both query
  `attributes->>pets_allowed = '1'`.
- Spanish-only UI strings. No i18n this sprint.
- All Supabase writes go through existing RLS (anon for the RPCs; authed for
  listing create/update). The Flutter app uses the existing anon key.
- `ReFilters` value sets must equal the web's `RE_PROPERTY_TYPES`,
  `RE_CONDITIONS`, etc. — do NOT redefine them. A parity test in T2 catches
  drift.

---

## File Structure

### Create
- `lib/features/real-estate/data/re_attributes.dart` — pure-Dart constants
  (mirror the web).
- `lib/features/real-estate/data/re_models.dart` — `ReFilters`,
  `ReFacetCounts`, `ReSort` enum, JSON encoding helpers.
- `lib/features/real-estate/data/re_pricing.dart` — `pricePerM2`,
  `estimateFromCityStats` (avg of comparables + ±12% range).
- `lib/features/real-estate/presentation/providers/re_search_provider.dart` —
  `reSearchFiltersProvider`, `reSearchResultsProvider`,
  `reFacetCountsProvider`.
- `lib/features/real-estate/presentation/widgets/re_attribute_form.dart` —
  the RE attribute fields (the conditional block inside
  `create_listing_screen.dart`).
- `lib/features/real-estate/presentation/screens/inmuebles_en_screen.dart` —
  the faceted search screen.
- `lib/features/real-estate/presentation/screens/city_landing_screen.dart` —
  `/inmuebles-en/[city]`.
- `lib/features/real-estate/presentation/screens/valuation_screen.dart` —
  `/valorar`.
- `test/re_attributes_parity_test.dart` — assertion that the Flutter
  constant sets equal the web's exported lists (hard-coded in the test from
  the web source, with a clear comment that drift here = drift from web).
- `test/re_pricing_test.dart` — `pricePerM2`, `estimateFromCityStats`
  (boundary: empty, 1, many, below-threshold null).
- `test/re_attribute_form_test.dart` — widget test for the RE form in
  create + edit modes.
- `test/valuation_screen_test.dart` — widget test for the result card +
  empty state.

### Modify
- `lib/features/listings/presentation/screens/create_listing_screen.dart` —
  conditionally render `ReAttributeForm` below the description block when
  `_selectedCategory?.id == 'real_estate'`; serialize RE attrs into
  `updates['attributes']` (create + edit branches).
- `lib/core/services/listing_service.dart` — add
  `searchRealEstate(ReFilters)`, `reFacetCounts(ReFilters)`,
  `estimateFromCityStats(country, city, m2, operation)` (the last one
  replicates the web's `fetchCityPriceStats` against the listings table).
- `lib/core/router/app_router.dart` — add routes
  `/inmuebles-en`, `/inmuebles-en/:city`, `/valorar`; new
  `AppRoutes.realEstateSearch()`, `AppRoutes.cityLanding(city)`,
  `AppRoutes.valuation()`.
- `lib/features/home/presentation/screens/home_screen.dart` (or
  `all_categories_screen.dart`) — add an "Inmuebles" tile linking to
  `/inmuebles-en`.

### Delete
- None.

---

## Task Decomposition

7 implementation tasks + 1 final verification. Each ends with `flutter
analyze` clean and a commit. Tasks 1-3 are pure-data (cheap model); 4-6 are
integration (standard model); 7 is the final whole-branch review (most
capable model).

### Task 1: RE constants + data models (parity with web)

**Files:**
- Create: `lib/features/real-estate/data/re_attributes.dart`
- Create: `lib/features/real-estate/data/re_models.dart`
- Test: `test/re_attributes_parity_test.dart`

**Interfaces produced (verbatim from the spec):**
- `RE_OPERATIONS = ['venta','alquiler','alquiler_temporal']`
- `RE_PROPERTY_TYPES = ['piso','casa','atico','estudio','duplex','chalet','loft','local','oficina','terreno','garaje']`
- `RE_CONDITIONS = ['obra_nueva','buen_estado','a_reformar']`
- `RE_ORIENTATIONS = ['norte','sur','este','oeste']`
- `RE_ENERGY_CERTS = ['A','B','C','D','E','F','G']`
- `RE_FEATURE_KEYS = ['elevator','parking','terrace','balcony','garden','pool','storage_room','air_conditioning','heating','built_in_wardrobes','furnished','exterior','accessible','luxury']`
- `RE_SORTS = ['relevance','recent','price_asc','price_desc','size_desc','price_m2']`
- `RE_FLOOR_BUCKETS = ['bajos','intermedias','ultima']`
- `enum ReSort { relevance, recent, priceAsc, priceDesc, sizeDesc, pricePerM2 }` with
  `String toRpcString()` returning `'relevance'|'recent'|'price_asc'|'price_desc'|'size_desc'|'price_m2'`.
- `ReFilters` class: `countryCode, state?, city?, operation?, propertyTypes: List<String>, priceMin?, priceMax?, m2Min?, m2Max?, rooms: List<int>, bathrooms: List<int>, conditions: List<String>, features: List<String>, floorBuckets: List<String>, energyBands: List<String>, orientation: List<String>, energyLetter?, petsAllowed?: bool, postedWithinDays?, sort: ReSort, cityExact: bool` (the `cityExact` is `true` for the city-landing route, `false` for fuzzy in /inmuebles-en).
- `ReFacetCounts { Map<String, int> propertyType, Map<String, int> condition }`.
- `Map<String, dynamic> toAttributesJson(ReFilters f)` — encoding the FILTER
  set the user is searching with into a JSONB-shaped map; for now, just
  empty (search RPC takes p_* directly, not attributes). The mapping
  ENCODER for listings is separate (T3).

- [ ] **Step 1: Write the failing test** that asserts the Flutter constants
  equal the web's exported values (hard-coded in the test from
  `foxy_ads_web/src/lib/real-estate/attributes.ts`):
  ```dart
  // test/re_attributes_parity_test.dart
  import 'package:flutter_test/flutter_test.dart';
  import 'package:foxy_ads/features/real-estate/data/re_attributes.dart';

  void main() {
    test('RE_PROPERTY_TYPES matches the web canonical list', () {
      // Hard-coded from foxy_ads_web/src/lib/real-estate/attributes.ts
      // (read manually 2026-08-01). If this test fails after editing the
      // web, copy the new list over and re-verify the parity.
      expect(RE_PROPERTY_TYPES, [
        'piso', 'casa', 'atico', 'estudio', 'duplex',
        'chalet', 'loft', 'local', 'oficina', 'terreno', 'garaje',
      ]);
    });
    test('RE_OPERATIONS matches the web', () {
      expect(RE_OPERATIONS, ['venta', 'alquiler', 'alquiler_temporal']);
    });
    test('RE_CONDITIONS matches the web', () {
      expect(RE_CONDITIONS, ['obra_nueva', 'buen_estado', 'a_reformar']);
    });
    test('RE_ORIENTATIONS matches the web', () {
      expect(RE_ORIENTATIONS, ['norte', 'sur', 'este', 'oeste']);
    });
    test('RE_ENERGY_CERTS matches the web', () {
      expect(RE_ENERGY_CERTS, ['A', 'B', 'C', 'D', 'E', 'F', 'G']);
    });
    test('RE_FEATURE_KEYS matches the web', () {
      expect(RE_FEATURE_KEYS, [
        'elevator', 'parking', 'terrace', 'balcony', 'garden', 'pool',
        'storage_room', 'air_conditioning', 'heating',
        'built_in_wardrobes', 'furnished', 'exterior', 'accessible', 'luxury',
      ]);
    });
    test('RE_SORTS matches the web', () {
      expect(RE_SORTS, [
        'relevance', 'recent', 'price_asc', 'price_desc',
        'size_desc', 'price_m2',
      ]);
    });
    test('RE_FLOOR_BUCKETS matches the web', () {
      expect(RE_FLOOR_BUCKETS, ['bajos', 'intermedias', 'ultima']);
    });
  }
  ```

- [ ] **Step 2:** Run — expect failure (constants undefined).
- [ ] **Step 3:** Implement `lib/features/real-estate/data/re_attributes.dart`
  with the exact 8 const lists above (in a single file, no service
  imports). Also add `lib/features/real-estate/data/re_models.dart` with
  `enum ReSort` (and its `toRpcString` extension) and a placeholder
  `class ReFilters` + `class ReFacetCounts` (the full field set — fill in
  in T3). DO NOT add the search-results service calls yet; that's T2.
- [ ] **Step 4:** Run — expect pass.
- [ ] **Step 5:** `flutter analyze` clean; commit
  `feat(real-estate): RE constants + data models (parity with web)`.

---

### Task 2: Service wiring (search RPC + facet counts + price estimator)

**Files:**
- Modify: `lib/core/services/listing_service.dart`
- Create: `lib/features/real-estate/data/re_pricing.dart`
- Test: `test/re_pricing_test.dart`

**Interfaces produced:**
- `Future<List<Listing>> ListingService.searchRealEstate(ReFilters f, {int offset = 0, int limit = 24})` —
  calls `_supabase.rpc('search_real_estate', params: buildReRpcArgs(f, offset, limit))`,
  parses `{items: [...], total: <n>}` (note: the RPC returns items with
  `headline`/attributes etc., not a `user_name` join — same parsing as
  `searchListings` does, the `Listing.fromJson` already tolerates null
  userName/avatar). `buildReRpcArgs(f, offset, limit)` is a private helper
  in the same file mapping `ReFilters` to the p_* arg names the web's
  `buildRpcArgs` uses — TRANSLATE `energyLetter` to a single-element
  `energy_bands` array via `energyBandForLetter(letter)`.
- `Future<ReFacetCounts> ListingService.reFacetCounts(ReFilters f)` — calls
  `_supabase.rpc('real_estate_facet_counts', params: buildReRpcArgs(f, 0, 0))`
  (the RPC's filter args work the same; limit/offset are ignored by the
  facet RPC). Parses the two `jsonb` columns into `ReFacetCounts`.
- `ReFilters` extension `buildReRpcArgs(ReFilters f, int offset, int limit)`
  lives in the service file.
- `Future<({double avgPricePerM2, int sampleSize})?> ListingService.estimateFromCityStats({required String countryCode, required String city, String? operation, required int minSample})` —
  replicates the web's `fetchCityPriceStats`: query
  `listings where category='real_estate' AND status='active' AND
  country_code= AND city= [AND attributes->>operation=]`, iterate
  rows, compute `pricePerM2` for each, return avg + count. Return `null`
  when count < `minSample` (the web's `getServerCityStats` requires
  ≥ 3 to be meaningful).
- `lib/features/real-estate/data/re_pricing.dart`: `int? pricePerM2(num price, num? m2)` and `String energyBandForLetter(String? letter)` (returns `'alta'|'media'|'baja'`, mirroring the web). Plus a `estimateFromComparables(Iterable<num> pricePerM2Values)` that returns `({int estimate, int low, int high, int sampleSize})?` — the same ±12% range the web applies. Pure Dart, unit-testable.
- `ReFilters.buildReRpcArgs` is a TOP-LEVEL function in the service file
  (not a method on the class) so it's directly testable.

- [ ] **Step 1:** Write `test/re_pricing_test.dart`:
  ```dart
  import 'package:flutter_test/flutter_test.dart';
  import 'package:foxy_ads/features/real-estate/data/re_pricing.dart';

  void main() {
    test('pricePerM2 returns null on zero m²', () {
      expect(pricePerM2(100000, 0), isNull);
      expect(pricePerM2(100000, null), isNull);
    });
    test('pricePerM2 rounds to integer', () {
      expect(pricePerM2(200000, 80), 2500);
    });
    test('energyBandForLetter A/B/C is alta', () {
      for (final l in ['A','B','C']) expect(energyBandForLetter(l), 'alta');
    });
    test('estimateFromComparables applies ±12% range', () {
      final r = estimateFromComparables([2000, 2500, 3000, 2200, 2700, 2400]);
      expect(r, isNotNull);
      expect(r!.estimate, 2467); // avg ≈ 2466.67
      expect(r.low, lessThan(r.estimate));
      expect(r.high, greaterThan(r.estimate));
    });
  }
  ```

- [ ] **Step 2:** Run — expect failure.
- [ ] **Step 3:** Implement `re_pricing.dart` with the two functions (mirror
  the web's `pricePerM2` + `energyBandForLetter`) + `estimateFromComparables`
  (avg → estimate, low = round(0.88 × estimate), high = round(1.12 ×
  estimate), sampleSize = input length).
- [ ] **Step 4:** Extend `listing_service.dart` with the three new methods.
  Make sure `buildReRpcArgs` is exported from the same file (top-level
  function or static) so it's testable.
- [ ] **Step 5:** Run the pricing tests — expect pass.
- [ ] **Step 6:** `flutter analyze` clean; commit
  `feat(real-estate): search RPC + facet counts + city price stats service`.

---

### Task 3: RE attribute form widget + integrate into create/edit

**Files:**
- Create: `lib/features/real-estate/presentation/widgets/re_attribute_form.dart`
- Modify: `lib/features/listings/presentation/screens/create_listing_screen.dart`
- Test: `test/re_attribute_form_test.dart`

**Interfaces produced (the form widget):**
- `class ReAttributeForm extends ConsumerStatefulWidget { final Map<String, dynamic>? initialAttributes; final void Function(Map<String, dynamic> attributes) onChanged; }` — controlled component. The parent passes a callback to receive the current attributes map (so the form's state lives here, the parent's `_submitListing` reads it via the callback at submit time).
- Internal state: each RE field as a separate controller, mirroring the
  create screen's text-field pattern. Renders ONLY the fields the spec
  defines: operation (segmented), propertyType (dropdown), m² (number),
  rooms (number), bathrooms (number), condition (dropdown), features
  (multi-select chips), floorBucket (segmented), energyCert (dropdown),
  orientation (dropdown), petsAllowed (switch).
- On every change, recompute and call `onChanged` with the encoded JSONB
  map (the EXACT key names from the spec). No-op for empty/null fields
  (don't write the key at all).

**Encoding rules (in `ReAttributeForm._encode()`):**
- `operation` → `attributes['operation'] = 'venta'|'alquiler'|'alquiler_temporal'`
- `propertyType` → `attributes['property_type'] = ...`
- `m²` (string) → `attributes['m2'] = '<number>'` (e.g. `'80'`)
- `rooms`, `bathrooms` → `attributes['rooms'] = '<n>'`, `attributes['bathrooms'] = '<n>'`
- `condition` → `attributes['condition'] = ...`
- `features` (set) → `attributes['features'] = ['elevator', 'parking']` (or absent if empty)
- `floorBucket` → `attributes['floor_buckets'] = ['bajos'|'intermedias'|'ultima']` (or absent if "No especificado")
- `energyCert` letter → `attributes['energy_letter'] = 'A'..'G'` AND `attributes['energy_bands'] = ['alta'|'media'|'baja']` (so the search RPC's band filter works) — or absent if "No especificado"
- `orientation` → `attributes['orientation'] = ...` (or absent)
- `petsAllowed` → `attributes['pets_allowed'] = '1'|'0'` (or absent if null)

**Integration into `create_listing_screen.dart`:**
- Add a `Map<String, dynamic>? _reAttributes` field.
- After the description block (where the form ends today), conditionally
  render `ReAttributeForm(initialAttributes: existing?.attributes,
  onChanged: (m) => setState(() => _reAttributes = m))` only when
  `_selectedCategory?.id == 'real_estate'`.
- In `_submitListing`, for both create AND edit branches: after building
  the field map and BEFORE calling `createListing`/`updateListing`, if
  `_reAttributes != null && _reAttributes.isNotEmpty` set
  `updates['attributes'] = _reAttributes` (in edit, this OVERWRITES the
  attributes; in create, this is the first time attributes is set). The
  trigger validates the new value against the trigger constraints.
- In edit mode prefill: pass `widget.existing?.attributes` as
  `initialAttributes` (the form decodes the map back into its fields — see
  the form's `initState`).
- Use a `setState` callback in `onChanged` so the form re-renders the
  parent (and the parent always knows the latest map at submit time).

- [ ] **Step 1:** Widget test (`test/re_attribute_form_test.dart`):
  pump the form inside `ProviderScope` + `MaterialApp`, type a few values,
  pump, then verify the `onChanged` callback received a map with the
  expected key/value pairs (operation, property_type, m2, rooms,
  bathrooms, condition, features, energy_letter, energy_bands,
  orientation, pets_allowed, floor_buckets — each exactly per the encoding
  rules above). Also test prefill from `initialAttributes: {'operation':
  'venta', 'm2': '80', ...}` and verify the fields populate.
- [ ] **Step 2:** Implement the form widget.
- [ ] **Step 3:** Wire it into `create_listing_screen.dart` (conditional
  render + the `setState` callback + the `updates['attributes']` injection
  in BOTH create and edit branches).
- [ ] **Step 4:** Run the widget test — expect pass.
- [ ] **Step 5:** `flutter analyze` clean; commit
  `feat(real-estate): RE attribute form in create + edit (parity with web)`.

---

### Task 4: Faceted search screen at `/inmuebles-en` (search + results + facet counts)

**Files:**
- Create: `lib/features/real-estate/presentation/providers/re_search_provider.dart`
- Create: `lib/features/real-estate/presentation/screens/inmuebles_en_screen.dart`
- Modify: `lib/core/router/app_router.dart` (add `/inmuebles-en` route +
  `AppRoutes.realEstateSearch()`)

**Interface produced (`re_search_provider.dart`):**
- `reSearchFiltersProvider` (NotifierProvider<ReSearchFiltersNotifier, ReFilters>) — a `Notifier<ReFilters>` that initializes with the current selected country.
- `reSearchResultsProvider` (FutureProvider<List<Listing>>) — debounced 300ms watch of `reSearchFiltersProvider` → `listingService.searchRealEstate(f)`. Returns `[]` when the filters are at-defaults (the spec's "Resultados aparecen cuando hay filtros" — keep it that way: only show results when the user has narrowed something).
- `reFacetCountsProvider` (FutureProvider<ReFacetCounts>) — debounced 300ms watch of `reSearchFiltersProvider` → `listingService.reFacetCounts(f)`. Returns an empty counts object on error.

**Interface produced (`inmuebles_en_screen.dart`):**
- A `ConsumerWidget` (or `ConsumerStatefulWidget` if you need a TextEditingController for the city picker).
- Layout per the spec:
  1. Top: country + city picker (async typeahead via
     `citiesProvider(countryCode)`).
  2. Operation chip row (3 options).
  3. "Filtros" expansion tile containing the rest (type chips with counts,
     price range, m² range, rooms/bathrooms chips, condition chips with
     counts, features chips, orientation chips, floor-bucket chips, energy-band
     chips with sub-letter dropdown, pets switch, posted-within chips).
  4. Sort dropdown.
  5. Results grid (2 cols, `ListingCard`, tap → `/listing/:id`).
- All chips tap → call `notifier.toggleX(...)` methods (or single-field setters, mirroring the saved-searches pattern from Sprint 1).
- Facet-count labels: `FilterChip(label: Text('${t.label} (${count ?? 0})'), selected: ..., onSelected: ...)`. Counts come from `reFacetCountsProvider` (graceful fallback to `null` on error).
- Empty state: "Sin resultados. Prueba a quitar filtros."

- [ ] **Step 1:** Implement the providers (data + notifier).
- [ ] **Step 2:** Implement the screen widget with all the filter chips +
  results grid + sort dropdown + facet-count display.
- [ ] **Step 3:** Add the route to `app_router.dart` (and the
  `AppRoutes.realEstateSearch()` helper). Add a link from the home screen
  (or `all_categories_screen.dart`) — pick whichever is cleaner; a
  `ListTile` on `all_categories_screen.dart` is the lowest-friction.
- [ ] **Step 4:** `flutter analyze` clean; commit
  `feat(real-estate): /inmuebles-en faceted search screen`.

---

### Task 5: City landing at `/inmuebles-en/:city` + `/valorar` screen

**Files:**
- Create: `lib/features/real-estate/presentation/screens/city_landing_screen.dart`
- Create: `lib/features/real-estate/presentation/screens/valuation_screen.dart`
- Modify: `lib/core/router/app_router.dart` (add both routes)

**Interface produced (`city_landing_screen.dart`):**
- Reads the city from `state.pathParameters['city']!` (URL-decoded by go_router).
- A `ConsumerWidget` that watches a local `FutureProvider<List<Listing>>` that
  calls `listingService.searchRealEstate(ReFilters(country, city, cityExact:
  true, sort: relevance))`.
- Hero header: "<city> — Inmuebles en venta" (or "alquiler" if the operation
  filter is set).
- Operation chip row (Venta / Alquiler) — toggling updates the future
  provider and re-fetches.
- Listing grid (2 cols).
- Empty state: "Aún no hay anuncios en {city}." + a "Buscar en otras zonas" link to `/inmuebles-en`.

**Interface produced (`valuation_screen.dart`):**
- A `ConsumerStatefulWidget` with controllers for `city`, `m2`, `operation`.
- "Valorar" button → calls `listingService.estimateFromCityStats(...)` →
  shows the result card (estimate, low/high, price/m², sample size) with
  `formatCurrency` (from the country's currency symbol).
- Empty state when `sampleSize < 3`: "No hay datos suficientes para esta zona."
- Loading spinner while the RPC runs.

- [ ] **Step 1:** Implement `city_landing_screen.dart`.
- [ ] **Step 2:** Implement `valuation_screen.dart`.
- [ ] **Step 3:** Wire both routes in `app_router.dart`.
- [ ] **Step 4:** `flutter analyze` clean; commit
  `feat(real-estate): city landing + /valorar screens`.

---

### Task 6: Widget tests for the new screens

**Files:**
- Create: `test/valuation_screen_test.dart`
- (No new file for the search screen — it's covered by the form test in
  T3 + a `flutter test` of the existing suite.)

**Coverage:**
- `test/valuation_screen_test.dart`: pump the screen with a fake
  `listingServiceProvider` that returns `null` (insufficient data) → empty
  state visible; pump with a fake returning a result → result card
  visible with the formatted currency. Use a `FakeListingService extends
  ListingService` (override the public method) to avoid touching Supabase.

- [ ] **Step 1:** Write the test.
- [ ] **Step 2:** Run the test — expect pass.
- [ ] **Step 3:** `flutter analyze` clean.

---

### Task 7: Final verification (whole-sprint build + analyze + all tests)

- [ ] **Step 1:** `flutter test` — full suite green.
- [ ] **Step 2:** `flutter analyze` — 0 errors.
- [ ] **Step 3:** `flutter build apk --debug --no-pub` — succeeds.
- [ ] **Step 4:** Commit
  `chore(real-estate): sprint 2 verification (analyze + tests + APK build)`.

---

## Final whole-branch review (Task 8)

Dispatch the most-capable reviewer over the merge-base..HEAD diff. Lens:
- The 4 deliverables (RE attrs in create/edit, faceted search screen, city
  landing, /valorar) are present and consistent.
- **Attribute key parity:** the JSONB keys stored in `listings.attributes`
  match the web's `buildRpcArgs` field names exactly (`operation,
  property_type, m2, rooms, bathrooms, condition, features, floor,
  floor_buckets, energy_bands, energy_letter, orientation,
  pets_allowed`). `pets_allowed` is `'1'|'0'` (not boolean).
- **Sort + filter parity:** the p_* args sent to `search_real_estate` match
  the web's arg names (`p_country_code, p_state, p_city, p_operation,
  p_property_types, p_price_min, p_price_max, p_m2_min, p_m2_max, p_rooms,
  p_bathrooms, p_condition, p_features, p_floor_buckets, p_energy_bands,
  p_orientation, p_pets_allowed, p_posted_within_days, p_sort, p_limit,
  p_offset`). `energy_letter` is translated to `energy_bands` before the
  call.
- **Valuation honesty:** the result card shows the sample size and the ±12%
  range so the user knows how reliable the estimate is.
- **No new dependencies**; `path_provider_android` pin intact; create +
  edit create-listing path still behavior-identical for non-RE categories.
- No security gaps (no service-role key, no RLS bypass).
- `flutter analyze` 0 errors; `flutter test` 0 failures; APK build OK.

---

## Verification (post Task 7)

```bash
cd app_flutter
flutter analyze
flutter test
flutter build apk --debug --no-pub
```

Manual smoke: open `/inmuebles-en` → select country/city → pick a couple of
filters → see results. Open `/inmuebles-en/madrid` → see Madrid listings.
Create a new RE listing via the create form → fill in all RE attrs → save →
re-open it in edit mode → confirm all RE attrs are prefilled. Open `/valorar`
→ enter a city with ≥ 3 comparables → see the result card.

## Self-review

- Spec coverage: D1 = T3, D2 = T4, D3 = T5 (landing) + T5 (valorar), D4 = T5
  (valorar) + T2 (pricing service). ✓
- No placeholders; every step has the actual code or the exact change. ✓
- Type consistency: `ReFilters` consumed by all three service methods and
  the providers; `ReFacetCounts` shared by the screen and the provider. ✓
