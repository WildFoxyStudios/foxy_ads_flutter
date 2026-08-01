# Flutter Sprint 4 — Agency / B2B (Design)

**Date:** 2026-08-01
**Status:** Approved (verbal)
**Scope:** Full-parity port of the web B2B/agency surface to the Flutter app,
EXCEPT Teams/roles (paused even in web), i18n of these screens (Spanish-only,
matching the app today), and the admin panel (stays web-only). Builds on
Sprints 1–3 (esp. the `developments/` module from Sprint 3).

## Goal

Give verified agencies the same B2B tools on mobile that `foxy_ads_web` has:
a public agency profile, an editable agency profile (with logo), and a Pro
Dashboard bundling Stats, a views chart, a CRM leads inbox, developments
management (CRUD + assign), bulk listing operations, and CSV export.

## Architecture

Client-side only — Riverpod 3 + go_router + Supabase, `core/` + `features/`
layers. All reads/writes go through the signed-in user's session under RLS
(NO service-role key in the client). New module `lib/features/agency/`
(`data/` + `presentation/{screens,widgets,providers}`), reusing the
`developments/` module (Sprint 3), the `Listing`/`ListingCard`/`LeadsService`
already present, `AppColors`, and the existing Supabase Storage upload path
(`ListingService.uploadImages`, Sprint 1). **No new dependencies** — the views
chart is a `CustomPainter`, and CSV export shares via the already-present
`share_plus`/`SharePlus`.

### The verification gate is a product gate, not a security boundary

On web, the bulk/lead/development WRITE actions call `requireVerifiedAgency()`,
which adds an `agency_profiles.is_verified` check ON TOP OF the RLS ownership
rules. The DB's RLS itself only enforces OWNERSHIP (`user_id` /
`agency_user_id`), never verification — an unverified authenticated user could
already create a development on web (only the panel UI gate stops them). Flutter
matches this exact posture: the `/panel` route and its entry tile are shown only
when `myAgencyProfileProvider` resolves to a profile with `isVerified == true`,
and each service method additionally filters by the caller's `user_id` (defense
in depth). Equivalent security to web; the real boundary is RLS ownership.

Verification (`is_verified`) is set by admins only — the
`agency_profiles_protect_verified` trigger blocks a user from self-verifying, so
`upsertAgencyProfile` never writes `is_verified`.

## Data layer

`lib/features/agency/data/agency_model.dart`:
- `class AgencyProfile { String userId; String name; String? logoUrl;
  String? description; String? website; String? phone; String? location;
  bool isVerified; String createdAt; }` + `factory AgencyProfile.fromRow(Map)`
  parsing snake_case (`user_id, name, logo_url, description, website, phone,
  location, is_verified, created_at`).
- `class AgencyInput { String name; String? logoUrl; String? description;
  String? website; String? phone; String? location; }`.
- `AgencyValidationError` enum `{ name, website, length }` + top-level
  `AgencyValidationError? validateAgencyInput(AgencyInput)`:
  - `name` (trim) 2–120 → else `name`.
  - `website` if present & non-empty must match `^https?://` (else `website`)
    and be ≤300 (else `length`).
  - `description` ≤2000, `location` ≤200, `phone` ≤40 → else `length`.
  Bounds mirror web `validateAgencyInput` exactly (parity-locked by test).

`lib/features/agency/data/lead_model.dart`:
- `const LEAD_STATUSES = ['new', 'contacted', 'closed']` + `LeadStatus` (a
  validated `String` or a small enum with `.wire` values matching those
  strings).
- `class Lead { String id; String? listingId; String? developmentId;
  String listingTitle; String ownerUserId; String? buyerUserId;
  String buyerName; String buyerEmail; String? buyerPhone; String message;
  String status; String? notes; String createdAt; String updatedAt; }`
  + `factory Lead.fromRow(Map)` (snake_case).

`lib/features/developments/data/development_model.dart` (EXTEND Sprint 3):
- `const DEVELOPMENT_STATUSES = ['planning', 'building', 'ready']` (already
  used implicitly by the Sprint 3 status badge — formalize as a const list).
- `class DevelopmentInput { String name; String? description;
  String? promoterName; String countryCode; String? city; String? address;
  double? latitude; double? longitude; List<String> amenities;
  List<String> images; String? deliveryLabel; String? status; }` +
  `Map<String,dynamic> toColumns()` (snake_case, trims, `status ??
  'planning'`, excludes `id`/`agency_user_id`).
- `DevelopmentValidationError` enum `{ name, country, status, description,
  length }` + `validateDevelopmentInput(DevelopmentInput)`: name 2–140 →
  `name`; country_code 2–5 → `country`; status if present ∈
  `DEVELOPMENT_STATUSES` → `status`; description ≤5000 → `description`;
  promoter ≤140 / city ≤120 / address ≤240 / delivery ≤60 → `length`. Mirrors
  web exactly (parity-locked by test).

## Services

`lib/features/agency/data/agency_service.dart` — `AgencyService(SupabaseClient)`:
- `Future<AgencyProfile?> fetchAgencyProfile(String userId)` — `agency_profiles`
  `.eq('user_id', userId).maybeSingle()`.
- `Future<({List<Listing> items, bool hasMore})> fetchAgencyListings(String
  userId, int page)` — `listings` `.eq('user_id').eq('status','active')` order
  created_at desc, range page×24 .. +23; `hasMore = items.length == 24`.
- `Future<AgencyProfile?> upsertAgencyProfile(String userId, AgencyInput)` —
  `.upsert({...columns, user_id: userId})` (NEVER writes `is_verified`);
  returns the row.
- `Future<String> uploadAgencyLogo(String userId, XFile)` — uploads to the
  existing storage bucket under an `agency-logos/<userId>/…` path, returns the
  public URL (mirror `ListingService.uploadImages`).
- Providers: `agencyServiceProvider` (Provider); `myAgencyProfileProvider`
  (FutureProvider<AgencyProfile?> — the signed-in user's own profile, the panel
  gate); `agencyProfileProvider` (FutureProvider.family<AgencyProfile?, String>);
  `agencyListingsProvider` (FutureProvider.family over `(userId, page)` — use a
  small record/args class).

`lib/core/services/leads_service.dart` (EXTEND — already has submitLead +
submitDevelopmentLead from Sprints 1/3):
- `Future<List<Lead>> listAgencyLeads({LeadStatus? status})` — `leads`
  `.eq('owner_user_id', currentUserId)` [+ `.eq('status', ...)` when a concrete
  status] order created_at desc. `[]` when signed-out or on error.
- `Future<LeadActionOutcome> updateLeadStatus(String id, String status)` —
  validate id (UUID) + status ∈ LEAD_STATUSES; `.update({status}).eq('id').
  eq('owner_user_id', uid)`.
- `Future<LeadActionOutcome> updateLeadNotes(String id, String notes)` — id
  UUID; trim; >4000 → invalidInput; empty → null; same scoped update.
- `LeadActionOutcome` mirrors `LeadActionResult` (`ok` + a code enum
  `{ unauthenticated, forbidden, invalidInput, databaseError }`).
- Providers: `agencyLeadsProvider` (FutureProvider.family<List<Lead>,
  LeadStatus?>) + `newLeadsCountProvider` (FutureProvider<int> over status=new).

`lib/features/developments/data/developments_service.dart` (EXTEND Sprint 3):
- `Future<DevActionOutcome<String>> createDevelopment(DevelopmentInput)` —
  validate; `.insert({...toColumns(), agency_user_id: uid}).select('id').
  single()`.
- `Future<DevActionOutcome> updateDevelopment(String id, DevelopmentInput)` —
  id UUID + validate; `.update(toColumns()).eq('id').eq('agency_user_id', uid)`.
- `Future<DevActionOutcome> deleteDevelopment(String id)` — id UUID; scoped
  delete.
- `Future<List<Development>> listMyDevelopments()` — `.eq('agency_user_id',
  uid)` order created_at desc.
- `Future<DevActionOutcome> assignListingsToDevelopment(String? developmentId,
  List<String> listingIds)` — parseIds; assert all listings owned by uid;
  when `developmentId != null` assert it's UUID AND owned by uid; then
  `.update({development_id: developmentId}).inFilter('id', ids).eq('user_id',
  uid)`. (Mirrors the web cross-table ownership guard.)
- `Future<List<String>> uploadDevelopmentImages(List<XFile>)` — reuse the
  storage upload path.
- `DevActionOutcome<T>` mirrors `DevelopmentActionResult` (code enum
  `{ unauthenticated, forbidden, invalidInput, databaseError }`).
- Providers: `myDevelopmentsProvider` (FutureProvider<List<Development>>).

`lib/core/services/listing_service.dart` (EXTEND — Sprints 1/2):
- `parseIds(List<String>) -> List<String>?` (1–100, UUID-shaped, dedup
  lowercase) + `applyPriceMode(double current, String mode, double value) ->
  double` (`set`→value; `pct`→current×(1+value/100); clamp ≥0, round 2dp) — pure,
  unit-tested, parity-locked against web `parseIds`/`applyPriceMode`.
- `bulkSetStatus(ids, status∈{active,inactive,sold})`, `bulkDelete(ids)`
  (→status=deleted), `bulkRenew(ids)` (→created_at=now, exclude deleted),
  `bulkSetPrice(ids, mode, value)` (fetch owned id+price, apply, per-row update)
  — each: parseIds → assertAllOwned (`.eq('user_id',uid).inFilter('id',ids).
  neq('status','deleted')` count == ids.length) → mutate; `PanelActionOutcome`.
- `getAgencyViewsSeries({int days = 30}) -> List<DayPoint>` — RPC
  `agency_daily_views(p_user_id: uid, p_days: days)`, coerce `{day, views}`
  (both may cross the wire as strings). `[]` on error.
- `listingsToCsv(List<Listing>) -> String` — RFC-4180 CSV (CRLF rows,
  quote-when-needed, doubled inner quotes), same column set/order as web
  `toListingsCsv`; the panel writes it to a temp file and shares via SharePlus.

`DayPoint { String day; int views; }` lives in the agency data layer.

## Presentation

### 1. Public agency profile — `/agencia/:id`

`lib/features/agency/presentation/screens/agency_profile_screen.dart`
(`ConsumerWidget`): watches `agencyProfileProvider(id)` and
`agencyListingsProvider((id, page))`. Header card: logo (or initial-letter
fallback), name, a verified badge (mirror the web `ProfessionalBadge`),
whitespace-pre-line description, and a row of website (launch via url_launcher)
/ phone / location. Then a heading + a grid of `ListingCard` (the agency's
active listings) with prev/next pagination (0-based `page` query, `hasMore`).
`null` profile → "Agencia no encontrada" scaffold. Route `/agencia/:id` +
`AppRoutes.agencyProfile(id)`. Entry point: on the listing detail's seller
section, when that seller has an agency profile, link "Ver agencia".

### 2. Agency profile edit — `/agencia/editar`

`agency_profile_edit_screen.dart` (`ConsumerStatefulWidget`): auth-gated (must
be signed in). Prefills from `myAgencyProfileProvider`. Form: name (required),
description, website, phone, location, and a logo picker (image_picker →
`uploadAgencyLogo` → preview). Client `validateAgencyInput`; on save
`upsertAgencyProfile`, invalidate `myAgencyProfileProvider`, SnackBar + pop.
Never exposes `is_verified`. Route `/agencia/editar` +
`AppRoutes.agencyEdit`.

### 3. Pro Dashboard — `/panel`

`panel_screen.dart` (`ConsumerWidget`): the GATE. Watches
`myAgencyProfileProvider`; when null/not verified → a "Panel Pro" explainer
scaffold with a CTA to `/agencia/editar` (mirrors web's `redirect('/perfil')`,
but in-app we show why). When verified, a scrollable dashboard composed of
section widgets:
- `panel_stats.dart` — 6 `StatCard`-style tiles aggregated in Dart over the
  agency's own listings (total/active/sold/views/featured/favorites); featured
  respects `featured_until` expiry. Favorites count via a second query
  (non-fatal → 0 on error), like web `fetchOwnerListingsForPanel`.
- `panel_views_chart.dart` — a `CustomPainter` line/bar chart over
  `getAgencyViewsSeries(days:30)`; empty/error → a muted "Sin datos" state.
- `leads_panel.dart` — CRM: a status filter (all/new/contacted/closed), a
  new-count badge, and a list of lead cards each with a status dropdown
  (`updateLeadStatus`), a notes textarea + Save (`updateLeadNotes`),
  buyer email (`mailto:`) + phone (`tel:`) + date, and a link to
  `/promocion/:id` when `developmentId != null`. Optimistic in-list update
  + Spanish error SnackBar on failure. Mirrors web `LeadsPanel`.
- `developments_panel.dart` — lists `myDevelopmentsProvider`; each row: edit
  (`/promocion-editar/:id`), delete (confirm), and an "Asignar anuncios"
  action. A "Crear promoción" button → `/promocion-editar`.
- `bulk_listings_panel.dart` — the agency's own listings with per-row
  checkboxes + select-all (current view), a bulk toolbar (set status / set
  price [set|pct] / renew / delete with a confirm), and an "Exportar CSV"
  button (share). Selection clears on a successful mutation. Mirrors the
  moderation-lock-free subset of web `PanelClient`.

Route `/panel` + `AppRoutes.panel`. Entry point: a "Panel Pro" tile in
`profile_screen.dart`, shown only when `myAgencyProfileProvider` is verified.

### 4. Development create/edit — `/promocion-editar` and `/promocion-editar/:id`

`development_form_screen.dart` (`ConsumerStatefulWidget`): auth + verified
gate. On `:id`, prefills from `developmentDetailProvider(id)` (Sprint 3);
otherwise a blank create form. Fields: name (required), description,
promoterName, countryCode (default the selected country), city, address,
latitude/longitude, amenities (add/remove chips), images (image_picker →
`uploadDevelopmentImages` → reorderable previews), deliveryLabel, status
(planning/building/ready). Client `validateDevelopmentInput`; save →
`createDevelopment`/`updateDevelopment`, invalidate `myDevelopmentsProvider`,
pop. An "Asignar anuncios" section (on edit) lists the agency's own listings
with checkboxes → `assignListingsToDevelopment`. Route
`/promocion-editar` + `/promocion-editar/:id` +
`AppRoutes.developmentCreate` / `AppRoutes.developmentEdit(id)`.

## Testing

- `test/agency_validation_test.dart` — `validateAgencyInput` bounds
  (parity-locked against web) + `validateDevelopmentInput` bounds.
- `test/panel_pure_test.dart` — `parseIds` (1–100, UUID, dedup) +
  `applyPriceMode` (set/pct/clamp/round) — parity-locked against web.
- `test/panel_stats_test.dart` — the Dart stats aggregation (featured expiry,
  sums) over a fixture of listing rows.
- `test/agency_profile_screen_test.dart` — public profile: `null` → not-found;
  a fake service with 0 listings → empty state; with N → N `ListingCard`s.
- `test/panel_gate_test.dart` — `/panel` with a non-verified/absent
  `myAgencyProfileProvider` shows the explainer (no dashboard); verified →
  dashboard sections present.
- `test/leads_panel_test.dart` — CRM: fake service returns leads → cards
  render; empty → empty state; a status change calls the service.
- Manual per phase: `flutter analyze` 0 errors, `flutter test` full suite
  green, `flutter build apk --debug` builds.

## Phased plan (one spec, phased plan, sequential SDD)

- **F1** — models + validation (`AgencyProfile`/`AgencyInput`/`validate…`,
  `Lead`/`LEAD_STATUSES`, `DevelopmentInput`/`validate…`/`DEVELOPMENT_STATUSES`)
  + `parseIds`/`applyPriceMode` + parity tests.
- **F2** — `AgencyService` + providers + public `/agencia/:id` screen + listing
  card grid + pagination.
- **F3** — agency profile edit `/agencia/editar` + logo upload.
- **F4** — Pro Dashboard shell + verified gate + `/panel` route + Stats tiles +
  views chart (CustomPainter) + `getAgencyViewsSeries`.
- **F5** — CRM leads inbox (`listAgencyLeads`/`updateLeadStatus`/
  `updateLeadNotes` + `leads_panel.dart`).
- **F6** — developments management: service CRUD + `assignListingsToDevelopment`
  + `development_form_screen.dart` + `developments_panel.dart`.
- **F7** — bulk listing ops (`bulkSetStatus/Delete/Renew/SetPrice`) +
  `bulk_listings_panel.dart` + CSV export/share.
- **F8** — entry points (profile "Panel Pro" tile, listing-detail "Ver agencia"
  link) + final whole-branch review.

## Out of scope (this sprint)

- Teams/roles (paused even in web).
- i18n of the agency/panel strings (Spanish-only, matching the app today).
- The admin panel (`admin-foxy`) — stays web-only.
- Any new charting/CSV/maps dependency — all done with native widgets +
  the already-present `share_plus`/`url_launcher`/`image_picker`.

## Risks

- **No server-action gate on mobile.** Mitigation: the verified gate is UI +
  `myAgencyProfileProvider`; every write is RLS-ownership-scoped + a defensive
  `.eq('user_id'/'agency_user_id', uid)` — the same real boundary web relies on.
- **Bulk ops on many rows.** Mitigation: `parseIds` caps at 100; `bulkSetPrice`
  is per-row (matches web); the panel operates on the current in-memory view.
- **Views chart without a chart lib.** Mitigation: a small `CustomPainter`
  over ≤30 daily points — trivially within a hand-rolled painter; no dep.
- **CSV column drift vs web.** Mitigation: `listingsToCsv` column set/order is
  parity-locked; RFC-4180 quoting matches `toListingsCsv`.
- **Logo/image uploads.** Mitigation: reuse the proven Sprint-1
  `uploadImages` storage path; validate content-type/size client-side.
