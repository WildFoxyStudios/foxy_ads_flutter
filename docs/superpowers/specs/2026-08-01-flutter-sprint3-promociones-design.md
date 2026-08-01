# Flutter Sprint 3 — Promociones / Obra Nueva (Design)

**Date:** 2026-08-01
**Status:** Approved (verbal)
**Scope:** The PUBLIC developments (promociones de obra nueva) flow — index +
detail. Builds on Sprints 1-2. The agency-side (create/manage a development,
`/promocionar/[id]`) is explicitly Sprint 4 (agency/B2B), NOT this sprint.
Admin panel stays web-only.

## Goal

Give buyers the two public developments screens the web has:
1. `/promociones` — an index of the developments in the visitor's selected
   country (grid of cards).
2. `/promocion/:id` — a development detail with hero, gallery, description,
   amenities, a typology table, the development's units (as listing cards),
   and a lead-capture form (`submit_development_lead` RPC).

## Architecture

Reuse the established stack — Riverpod 3 + go_router + Supabase, `core/` +
`features/` layers. The `developments` table, the units relation
(`listings.development_id`), and the `submit_development_lead` RPC are
already in place — **no new DB schema or RPCs**. Sprint 3 is client-side:
data models + a service + providers + two screens + one card widget, plus
one method on the existing `LeadsService`.

**No new dependencies.** The location map (Leaflet on web) is replaced with an
"Abrir en mapas" button that opens the device's maps app via `url_launcher`
(already a dependency), avoiding a heavy `google_maps_flutter`/`flutter_map`
addition. A static coordinate line is shown alongside.

## Data layer

- `lib/features/developments/data/development_model.dart`:
  - `class Development` mirroring the `developments` columns: `id, agencyUserId,
    name, description?, promoterName?, countryCode, city?, address?, latitude?,
    longitude?, amenities: List<String>, images: List<String>, deliveryLabel?,
    status ('planning'|'building'|'ready'), createdAt`. `factory
    Development.fromRow(Map<String,dynamic>)` parsing snake_case columns.
  - `class DevelopmentCardData extends Development` (or a wrapper) adding
    `priceFrom: double?`, `currency: String?`, `unitCount: int` — the extra
    fields the index card needs, computed from the units aggregate.
  - `class Typology { int rooms; int count; double? priceFrom; int? m2Min;
    int? m2Max; }` — a room-count bucket for the detail typology table.
  - Top-level `List<Typology> aggregateTypologies(List<Listing> units)` — port
    of the web's `aggregateTypologies`: bucket units by
    `attributes['rooms']` (parsed as int), each bucket's `priceFrom` = min
    price, `m2Min`/`m2Max` = min/max of `attributes['m2']`, `count` = bucket
    size. Units with no `rooms` attribute are skipped (matches web). Sorted
    by `rooms` ascending. Pure Dart, unit-testable.

## Deliverable 1 — DevelopmentsService

`lib/features/developments/data/developments_service.dart`:
- `Future<List<DevelopmentCardData>> fetchDevelopmentsForCountry(String countryCode, {String? city, int limit = 60})` —
  1. Query `developments` where `country_code = countryCode` [`AND city ILIKE
     %city%` when city given], `ORDER BY created_at DESC LIMIT limit`.
  2. For those development ids, fetch active units in one query:
     `listings where development_id IN (...) AND status='active'` selecting
     `development_id, price, currency`.
  3. Fold the units into each development: `priceFrom` = min unit price,
     `currency` = first unit's currency (developments share the agency's
     currency), `unitCount` = number of units. Developments with zero units
     get `priceFrom=null, currency=null, unitCount=0` (still shown — matches
     web, so an agency's brand-new development isn't hidden).
- `Future<Development?> fetchDevelopment(String id)` — single row or null.
- `Future<List<Listing>> fetchDevelopmentUnits(String id)` — `listings where
  development_id = id AND status='active' ORDER BY price ASC`, parsed via the
  existing `Listing.fromJson` (units are real listings; `attributes` carries
  rooms/m2 for the typology table).
- `developmentsServiceProvider` (Provider) + providers:
  - `developmentsForCountryProvider` (FutureProvider<List<DevelopmentCardData>>)
    watching `selectedCountryProvider`.
  - `developmentDetailProvider` (FutureProvider.family<Development?, String>).
  - `developmentUnitsProvider` (FutureProvider.family<List<Listing>, String>).

## Deliverable 2 — Development lead capture

Extend the existing `LeadsService`
(`lib/core/services/leads_service.dart`, built in an earlier session with
`submitLead`) with:
- `Future<LeadSubmitOutcome> submitDevelopmentLead({required String
  developmentId, required String name, required String email, required String
  message, String? phone, String honeypot = ''})` — same shape as `submitLead`
  but calls the `submit_development_lead` RPC with `p_development_id`. Same
  honeypot short-circuit, same client-side `validate(...)`, same
  Postgres-error → `LeadSubmitError` mapping.

The detail screen reuses the SAME contact-sheet UX pattern as the listing
detail's `contact_sheet.dart` (name/email/phone/message + honeypot), just
pointed at the development lead method — a new
`lib/features/developments/presentation/widgets/development_contact_sheet.dart`
(or a parameterization of the existing sheet if clean).

## Deliverable 3 — `/promociones` index screen

`lib/features/developments/presentation/screens/promociones_screen.dart`:
- A `ConsumerWidget` watching `developmentsForCountryProvider`.
- AppBar "Promociones" (`AppColors.primary`).
- `.when`: loading → spinner; error → error state; data → if empty, an empty
  state ("Aún no hay promociones en {country}."); else a 2-col grid of
  `DevelopmentCard`.
- Route `/promociones` + `AppRoutes.promociones`.
- Entry point: a "Promociones / Obra nueva" tile in `all_categories_screen.dart`
  (next to the Sprint 2 "Inmuebles" tile).

### DevelopmentCard widget

`lib/features/developments/presentation/widgets/development_card.dart`:
- Mirrors the web's `DevelopmentCard`: cover image (first of `images`, or a
  🏠 fallback when empty), name (2-line clamp), city, and a price line —
  "Desde {priceFrom}" when a price exists, else "Precio a consultar" — plus a
  "{unitCount} viviendas" badge when `unitCount > 0`.
- Tap → `context.push('/promocion/${dev.id}')`.
- Uses `CachedNetworkImage` (already a dependency, used by `ListingCard`).

## Deliverable 4 — `/promocion/:id` detail screen

`lib/features/developments/presentation/screens/promocion_detail_screen.dart`:
- Reads `id` from the route param; watches `developmentDetailProvider(id)` and
  `developmentUnitsProvider(id)`.
- On `development == null` → "Promoción no encontrada" scaffold.
- Sections (mirroring the web, top to bottom):
  1. **Hero** — name + a status badge ("En planos" / "En construcción" /
     "Lista para entrar" for planning/building/ready), promoter line
     ("Promotora: {promoterName}"), a location line ("{city} · {address}"),
     and a delivery line ("Entrega: {deliveryLabel}") when present.
  2. **Gallery** — a horizontal `PageView`/`ListView` of the `images`
     (`CachedNetworkImage`); omitted when there are no images.
  3. **Description** — `whitespace-pre-line`-style text; omitted when empty.
  4. **Amenities** — wrap of chips; omitted when empty.
  5. **Location** — a text line with `city · address` + a coordinate line,
     and an "Abrir en mapas" `OutlinedButton` (only when latitude/longitude
     are finite and non-zero) that launches
     `https://www.google.com/maps/search/?api=1&query=<lat>,<lng>` via
     `launchUrl(..., mode: externalApplication)`.
  6. **Typología** — a table (rooms | nº viviendas | desde | m² rango) built
     from `aggregateTypologies(units)`; omitted when there are no typed units.
  7. **Viviendas (units)** — a 2-col grid of `ListingCard` (each unit is a
     real listing → tap goes to `/listing/:id`); "Aún no hay viviendas
     publicadas" empty state when there are no units.
  8. **Contacto** — a "Contactar con la promotora" button that opens the
     development contact sheet (`submitDevelopmentLead`). Requires auth is NOT
     mandatory (the RPC is anon-callable, matching the web's public lead form);
     the honeypot + validation are the guardrails.
- Route `/promocion/:id` + `AppRoutes.promocionDetail(id)`.

## Testing

- Unit test `test/development_typology_test.dart`: `aggregateTypologies` —
  empty units → empty; units bucketed by rooms; priceFrom = min; m2 range;
  units without `rooms` skipped; sorted ascending.
- Unit test `test/development_model_test.dart`: `Development.fromRow` parses a
  snake_case row (including null-able columns + `amenities`/`images` arrays).
- Widget test `test/promociones_screen_test.dart`: with a fake service
  returning `[]` → empty state; returning 2 cards → 2 `DevelopmentCard`s
  render.
- Manual: `flutter analyze` 0 errors; `flutter test` full suite green;
  `flutter build apk --debug` builds.

## Out of scope (this sprint)

- Agency-side: creating/editing a development, `/promocionar/[id]`, the Pro
  Dashboard's developments panel — all Sprint 4.
- An in-app interactive map (deferred to avoid a heavy new dependency; the
  "Abrir en mapas" launcher covers the buyer's need to see the location).
- i18n of the developments strings (Spanish-only, matching the app today).
- Pagination of the index (matches the Sprint 2 /inmuebles-en scope — the
  60-cap is generous for a country's development count).

## Risks

- **Units query with `IN (...)`** on many development ids could be large.
  Mitigation: cap the index at 60 developments; the units query selects only
  `development_id, price, currency` (3 columns), so even 60×N units is small.
- **`aggregateTypologies` reading `attributes`** — units created before
  Sprint 2 may have no `rooms`/`m2` in `attributes`. Mitigation: the aggregate
  skips units with no `rooms` (matches web); the typology table is omitted
  when empty, so a development with untyped units still renders its unit grid.
- **Lead sheet duplication** — the development contact sheet is nearly
  identical to the listing `contact_sheet.dart`. Mitigation: if the shared
  fields are extractable cleanly, parameterize; otherwise a focused copy is
  acceptable (the two lead RPCs differ in their id param).
