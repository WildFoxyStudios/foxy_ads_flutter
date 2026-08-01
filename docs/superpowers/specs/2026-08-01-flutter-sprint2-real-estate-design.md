# Flutter Sprint 2 — Real-Estate Vertical (Design)

**Date:** 2026-08-01
**Status:** Approved (verbal)
**Scope:** Bring the Flutter app's real-estate vertical to parity with the
web's `/inmuebles-en` flow. Builds on Sprint 1 (edit + saved searches +
FTS search + lead/report). Sprint 3 (promotions) and Sprint 4 (agency/B2B)
come after. Admin panel stays web-only.

## Goal

Make real-estate a first-class vertical in the Flutter app: structured
attributes on create/edit, a faceted search screen at `/inmuebles-en`, a
city landing at `/inmuebles-en/[city]`, and a `/valorar` (price-estimate)
flow.

## Architecture

Reuse the established stack — Riverpod 3 + go_router + Supabase, same
core/features layout. The web's RPCs (`search_real_estate`,
`real_estate_facet_counts`) and the `listings.attributes` JSONB column
(validated server-side by trigger `trg_validate_listing_attributes`) are
already in place. **No new DB schema or RPCs.** Sprint 2 is essentially
client-side: UI + service methods + provider wiring that calls the existing
Supabase surface.

## Source-of-truth constants (copy from web, do not redefine)

The web keeps the canonical value sets in
`foxy_ads_web/src/lib/real-estate/attributes.ts`. Flutter needs the same
constants to drive chips, dropdowns, and validation. **Single direction
of truth:** we copy the values into a new Flutter file (this is appropriate
because the canonical lists change ~twice a year when a new subcategory is
added; copy + manual sync is fine — the validation trigger will reject any
value that drifts from the DB anyway).

- `lib/features/real-estate/data/re_attributes.dart` — pure-Dart constants
  matching the web:
  - `RE_OPERATIONS = ['venta','alquiler','alquiler_temporal']`
  - `RE_PROPERTY_TYPES = ['piso','casa','atico','estudio','duplex','chalet','loft','local','oficina','terreno','garaje']`
  - `RE_CONDITIONS = ['obra_nueva','buen_estado','a_reformar']`
  - `RE_ORIENTATIONS = ['norte','sur','este','oeste']`
  - `RE_ENERGY_CERTS = ['A','B','C','D','E','F','G']` (with band mapping
    `A/B/C→alta`, `D/E→media`, `F/G→baja` — mirrors `energyBandForLetter`)
  - `RE_FEATURE_KEYS = ['elevator','parking','terrace','balcony','garden','pool','storage_room','air_conditioning','heating','built_in_wardrobes','furnished','exterior','accessible','luxury']`
  - `RE_SORTS = ['relevance','recent','price_asc','price_desc','size_desc','price_m2']`
  - `RE_FLOOR_BUCKETS = ['bajos','intermedias','ultima']`
  - `enum FloorBucket { bajos, intermedias, ultima }` with `fromFloor(floor?: String)` mapping the floor string ("bajo","entresuelo","atico" etc.) to a bucket — mirrors the web's `floorBucket()`.

These are pure data, no I/O. They live in `data/` (no service dep) so any
feature file can import them.

## Deliverable 1 — RE attributes in create / edit listing

**Approach:** conditionally render an RE attribute form below the existing
title/description/price block in `CreateListingScreen`, ONLY when
`_selectedCategory?.id == 'real_estate'`. Same conditional prefill in edit mode.

**RE attribute fields (the form):**
- **operation** — segmented control: Venta / Alquiler / Alquiler temporal. Required.
- **propertyType** — dropdown of `RE_PROPERTY_TYPES` (human-readable label + value). Required.
- **m²** — number field. Required, > 0.
- **rooms** — number field. Required, ≥ 1.
- **bathrooms** — number field. Required, ≥ 1.
- **condition** — dropdown of `RE_CONDITIONS`.
- **features** — multi-select chip group of `RE_FEATURE_KEYS` (toggles, not exclusive).
- **floorBucket** — segmented control of `RE_FLOOR_BUCKETS` (with a "No especificado" option that stores nothing in attributes).
- **energyCert** — dropdown of `RE_ENERGY_CERTS` (with the "No especificado" option).
- **orientation** — dropdown of `RE_ORIENTATIONS`.
- **petsAllowed** — switch (true/false; null when unset).

**Storage mapping** — when posting to `listings.attributes`, each field is
stored under the EXACT key the web uses (so the RPC's `attributes->>key`
predicates match):
- `operation` (text), `property_type` (text), `m2` (number-as-text), `rooms`
  (number-as-text), `bathrooms` (number-as-text), `condition` (text),
  `features` (array of text), `floor` (text — raw floor string or empty for
  bucket-null), `floor_buckets` (array of text), `energy_bands` (array of
  text), `energy_letter` (single text — the raw `A`..`G` for the detail page
  rendering, alongside `energy_bands` for the search), `orientation` (text),
  `pets_allowed` (text '1' / '0' — Supabase JSONB has no native boolean
  facet; the web uses `'1'`/`'0'` strings). Omit keys that are empty/null.
  This matches the trigger's expectations and the RPC's
  `attributes->>operation` etc. predicates exactly.

**Form validation client-side** mirrors the trigger (defense-in-depth):
required `operation`/`property_type`/`m2`/`rooms`/`bathrooms` for real_estate
category. The trigger rejects any non-conforming write server-side anyway.

**File changes:** extend `create_listing_screen.dart` (the only file
touched for create+edit since the form is already shared). The conditional
`if (_selectedCategory?.id == 'real_estate')` wraps the new widget; non-RE
categories see no change. Edit mode prefills RE attrs from
`existing.attributes`.

## Deliverable 2 — Faceted RE search screen at `/inmuebles-en`

**Approach:** a new full-page search screen that wires the existing
`search_real_estate` RPC into the search-results provider. Distinct from the
global `/search` because RE has far more filter axes (operation, type, m²,
rooms, etc.) and benefits from a dedicated UI.

**UI shape** (single scrollable screen, mobile-first):
1. Top: country + city picker. Default to `selectedCountryProvider`. City is
   an async dropdown (`_supabase.from('cities')...ilike`) — type-to-search.
2. Horizontal chip row for **operation** (Venta/Alquiler/Alquiler temporal).
3. Collapsible "Filtros" panel:
   - **Tipo de propiedad** — multi-select chips from `RE_PROPERTY_TYPES`, with
     live counts from `real_estate_facet_counts` when the user has already
     selected a city.
   - **Precio** — min/max.
   - **Superficie (m²)** — min/max.
   - **Habitaciones** — multi-select chips of {1, 2, 3, 4, 5+}.
   - **Baños** — multi-select chips of {1, 2, 3+}.
   - **Estado** — multi-select chips from `RE_CONDITIONS` (with counts).
   - **Características** — multi-select chips from `RE_FEATURE_KEYS`.
   - **Orientación** — multi-select chips from `RE_ORIENTATIONS`.
   - **Planta** — multi-select chips from `RE_FLOOR_BUCKETS`.
   - **Cert. energético** — multi-select chips of energy BANDS (alta/media/baja),
     not letters — the facet RPC uses bands. UI also has a "Carta" sub-section
     that lets the user pick a specific letter (A..G) which is stored as
     `energy_letter` in the filter and translated to band when sent to the RPC.
   - **Mascotas** — switch (true / false / any).
   - **Publicado en los últimos** — chips {1d, 7d, 30d, 90d, all}.
4. **Sort** dropdown: Relevancia / Más recientes / Precio ↑ / Precio ↓ / Tamaño ↓ / Precio/m² ↑.
5. Results grid (2 cols) below — same `ListingCard` widget as the home +
   /search screens; tapping goes to `/listing/:id`.

**Behavior:**
- Every filter change re-fires the search (debounced 300ms).
- Empty results show a "Sin resultados" empty state.
- Counts in the chip labels come from the separate `real_estate_facet_counts`
  RPC and update on country/city/operation/price/m² changes.

**Providers:**
- `reSearchFiltersProvider` (NotifierProvider) — mirrors the
  `searchFiltersProvider` pattern but typed `ReFilters` (with the extra RE axes).
- `reSearchResultsProvider` (FutureProvider) — calls
  `listingService.searchRealEstate(filters)`, returns `List<Listing>`.
- `reFacetCountsProvider` (FutureProvider.family<FacetCounts, FacetArgs>)
  — calls `listingService.reFacetCounts(filters)`, returns
  `ReFacetCounts { propertyType: Map<String,int>, condition: Map<String,int> }`
  (the RPC only returns these two — that's the source-of-truth, not a UI choice).

**Service additions (extend `listing_service.dart`):**
- `Future<List<Listing>> searchRealEstate(ReFilters f)` — calls
  `_supabase.rpc('search_real_estate', params: buildRpcArgs(f, 0, 24))`,
  parses `{ items: [...], total: N }` and returns the items.
- `Future<ReFacetCounts> reFacetCounts(ReFilters f)` — calls
  `_supabase.rpc('real_estate_facet_counts', params: ...)`, parses the two
  `jsonb` maps.
- `Map<String, dynamic> buildReRpcArgs(ReFilters f, int offset, int limit)`
  — the SAME arg-name mapping the web's `buildRpcArgs` uses
  (`p_country_code, p_state, p_city, p_operation, p_property_types[], p_price_min,
  p_price_max, p_m2_min, p_m2_max, p_rooms[], p_bathrooms[], p_condition[],
  p_features[], p_floor_buckets[], p_energy_bands[], p_orientation[],
  p_pets_allowed, p_posted_within_days, p_sort, p_limit, p_offset`). Translation
  of the `energy_letter` → `energy_bands` (single-element array of the band
  the letter maps to) happens here.

**Route:** `/inmuebles-en` (and `/inmuebles-en/[city]` — see D3).
- Add to `app_router.dart`: `GoRoute(path: '/inmuebles-en', ...)` and
  `GoRoute(path: '/inmuebles-en/:city', ...)` (URL-decoded city name).
- Entry point: a new "Inmuebles" category tile on the home screen (next
  to "Buscar") OR a tile inside `/categories`. Recommend the latter to
  match the web's IA where `/inmuebles-en` is the RE-specific hub.

**Sort default:** `relevance` (matches web).

## Deliverable 3 — City landing at `/inmuebles-en/[city]`

**Approach:** a route variant of the search screen, pre-filtered to one
city. The `[city]` path param is the URL-encoded city name (matches the
web's `citySlug()`: lowercase, hyphens for spaces, percent-encoded). The
screen renders an SEO-style hero with the city name + a listing grid
filtered by `p_city = city`.

**UI:**
- Hero: `<cityName> — Inmuebles en venta/alquiler` (text depends on active
  `operation` filter).
- Inline filter chips for operation (Venta/Alquiler).
- Grid (2 cols) of `ListingCard`.

**Data:** same `searchRealEstate` RPC with `p_city` set; no facet counts
on this view (they're not useful at the city level — the user has already
narrowed by city).

**Edge cases:** if the city has zero listings, show an empty state with a
link to `/inmuebles-en` (the un-narrowed search).

## Deliverable 4 — Property valuation at `/valorar`

**Approach:** a simple form that asks for `city + m² + operation`, calls
`_supabase.from('listings').select('price, attributes').eq('category_id',
'real_estate').eq('status','active').eq('country_code',...).eq('city',...)
[.eq('attributes->>operation', op)]`, computes the average price-per-m²
in Dart (mirroring the web's `pricePerM2`), and shows an estimate ±12%
range. **No server RPC needed** — replicates the web's
`fetchCityPriceStats` calculation client-side. Country currency is derived
from the selected country (default `EUR`).

**UI:**
- City picker (same as in `/inmuebles-en`).
- `m²` — number field.
- `operation` — segmented control.
- "Valorar" button.
- Result card: estimated value (formatted with currency symbol), low/high
  range, price-per-m² benchmark, sample size used.
- "No hay datos suficientes" empty state when the city has < 3 comparable
  listings.

**Honesty constraint:** the screen shows the `sampleSize` so the user knows
how reliable the estimate is. This matches the web's `ValuationForm` and
mirrors the "tu piso se vende por X en esta zona" promise without
overstating it.

**File changes:** new
`lib/features/real-estate/presentation/screens/valuation_screen.dart` + a
small `lib/features/real-estate/data/re_pricing.dart` (the `pricePerM2`
helper + the avg-computation function — pure Dart, unit-testable).

## Data layer

- `lib/features/real-estate/data/re_attributes.dart` — the constants block.
- `lib/features/real-estate/data/re_pricing.dart` — `pricePerM2`,
  `estimateFromCityStats(country, city, m2, operation)` (the avg-of-comparables
  calculation; returns `null` when < 3 comparables).
- `lib/features/real-estate/data/re_models.dart` — `ReFilters` (the
  serializable filter set), `ReFacetCounts`, `ReSort` enum.
- `lib/features/real-estate/presentation/providers/re_search_provider.dart` —
  `reSearchFiltersProvider`, `reSearchResultsProvider`, `reFacetCountsProvider`.
- Extend `lib/core/services/listing_service.dart` with the two RPC wrappers
  and `buildReRpcArgs`.

## Testing

- Unit tests for `re_attributes.dart` constants against the web's
  `attributes.ts` (parity check: identical value sets).
- Unit tests for `re_pricing.dart`: `pricePerM2` (zero/positive m²),
  `estimateFromCityStats` (empty input, single value, multiple values
  average, below-threshold returns null).
- Widget test: the new `CreateListingScreen` RE-attributes section
  appears when `categoryId == 'real_estate'`, prefills from
  `existing.attributes` in edit mode, validates required fields, and
  serializes them to the correct `attributes` JSON keys.
- Widget test: `/valorar` form shows the result card on success and the
  empty state on insufficient data.
- Manual: `flutter analyze` 0 errors; `flutter build apk --debug` builds.

## Out of scope (this sprint)

- Sprint 3 (Promociones / obra nueva) and Sprint 4 (Agency/B2B).
- i18n translations of RE strings (Spanish-only strings; the chips/labels
  are short and Spanish).
- A web parity detail: the web's `/inmuebles-en` page also shows
  aggregate city-level price stats on the city landing. Deferred — the
  listing grid + search filters cover the same buyer need via the faceted
  search screen.
- Editing the RE attributes when an existing listing was created before
  Sprint 2 (i.e. has no `attributes.m2`/`rooms`/etc.) — handled gracefully
  (form starts empty, valid triggers fire on next save).
- Re-bumping the `search_vector` on attribute edits (assumed already
  handled by the existing trigger on UPDATE; verify during implementation).

## Risks

- **Long screens in mobile** — `/inmuebles-en` has many filter chips.
  Mitigation: collapse everything except country/city/operation/sort into a
  "Filtros" sheet that slides up; results stay visible below.
- **JSONB attribute schema drift** between web and Flutter (e.g. web uses
  `'1'` for `pets_allowed`, Flutter could write `true`). Mitigation: the
  `RE_ATTRIBUTE_ENCODER` is a single function used by BOTH create and edit,
  shared via a unit test that asserts the JSON keys match the web's
  `buildRpcArgs` field names.
- **Cost of facet RPC per chip change** — every chip toggle could re-fire
  `real_estate_facet_counts`. Mitigation: debounce 300ms (same as results);
  fetch the same counts even with current filter set, the user just sees the
  effect of each toggle.
- **The web's RE lib has its own `provider` indirection** (`reSearchClient`).
  Flutter skips this — it just calls the RPC directly with the supabase
  client. Simpler, same result.
