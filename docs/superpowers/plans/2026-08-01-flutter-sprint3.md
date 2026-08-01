# Flutter Sprint 3 — Promociones / Obra Nueva — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the public developments (promociones de obra nueva) flow to the
Flutter app — a `/promociones` index and a `/promocion/:id` detail — reaching
parity with the web's public developments pages. Agency-side (create/manage)
is Sprint 4.

**Architecture:** Riverpod 3 + go_router + Supabase. The `developments` table,
the `listings.development_id` units relation, and the `submit_development_lead`
RPC already exist — **no new schema or RPCs**. Client-side only: a model, a
service, providers, two screens, a card widget, one `LeadsService` method.

**Tech Stack:** Flutter 3.44 / Dart 3.12, flutter_riverpod ^3, go_router ^17,
supabase_flutter ^2, cached_network_image ^3, url_launcher ^6 (all existing).

## Global Constraints

- `flutter analyze` **0 errors** after every task (pre-existing deprecation
  `info`s + the 8 RE `constant_identifier_names` infos are acceptable).
- `flutter test` full suite green after the final task; `flutter build apk
  --debug --no-pub` succeeds after the final task.
- **No new dependencies.** `path_provider_android` stays pinned `2.2.23`.
- The in-app map is replaced by an "Abrir en mapas" `url_launcher` button —
  do NOT add `google_maps_flutter`/`flutter_map`.
- The development lead RPC (`submit_development_lead`) is anon-callable —
  the contact sheet does NOT require auth (matches the web public lead form);
  honeypot + client validation are the guardrails.
- Spanish-only UI strings.
- All reads/writes go through existing RLS. The units query and developments
  query select only public/active rows.
- Reuse the existing `ListingCard` (units) and `CachedNetworkImage` (images);
  do not reimplement them.

## File Structure

### Create
- `lib/features/developments/data/development_model.dart` — `Development`,
  `DevelopmentCardData`, `Typology`, `aggregateTypologies`.
- `lib/features/developments/data/developments_service.dart` — the service +
  providers.
- `lib/features/developments/presentation/widgets/development_card.dart`.
- `lib/features/developments/presentation/widgets/development_contact_sheet.dart`.
- `lib/features/developments/presentation/screens/promociones_screen.dart`.
- `lib/features/developments/presentation/screens/promocion_detail_screen.dart`.
- `test/development_typology_test.dart`
- `test/development_model_test.dart`
- `test/promociones_screen_test.dart`

### Modify
- `lib/core/services/leads_service.dart` — add `submitDevelopmentLead(...)`.
- `lib/core/router/app_router.dart` — add `/promociones` + `/promocion/:id`
  routes + `AppRoutes.promociones` + `AppRoutes.promocionDetail(id)`.
- `lib/features/listings/presentation/screens/all_categories_screen.dart` —
  add a "Promociones / Obra nueva" tile.

### Delete
- None.

## Task Decomposition

6 implementation tasks + 1 final whole-branch review. Tasks 1-2 pure-data +
service (cheap→standard model); 3-5 UI + lead (standard); 6 tests +
verification; 7 final review (most-capable).

---

### Task 1: Development model + typology aggregation

**Files:**
- Create: `lib/features/developments/data/development_model.dart`
- Test: `test/development_typology_test.dart`, `test/development_model_test.dart`

**Interfaces produced:**
- `class Development { final String id; final String agencyUserId; final String name; final String? description; final String? promoterName; final String countryCode; final String? city; final String? address; final double? latitude; final double? longitude; final List<String> amenities; final List<String> images; final String? deliveryLabel; final String status; final DateTime createdAt; ... factory Development.fromRow(Map<String,dynamic>); }`
- `class DevelopmentCardData extends Development { final double? priceFrom; final String? currency; final int unitCount; }` (constructor takes a `Development` + the three aggregate fields).
- `class Typology { final int rooms; final int count; final double? priceFrom; final int? m2Min; final int? m2Max; const Typology(...); }`
- `List<Typology> aggregateTypologies(List<Listing> units)` — bucket by
  `attributes['rooms']` (parsed `int` — may be a String `'3'` or an int; use
  `int.tryParse(v.toString())`), skip units without a parseable `rooms`;
  each bucket: `count` = size, `priceFrom` = min price, `m2Min`/`m2Max` =
  min/max of `attributes['m2']` (parsed `int`); sort ascending by `rooms`.

- [ ] **Step 1: Write the failing test** `test/development_typology_test.dart`:
  ```dart
  import 'package:flutter_test/flutter_test.dart';
  import 'package:foxy_ads/core/models/listing_model.dart';
  import 'package:foxy_ads/features/developments/data/development_model.dart';

  Listing _unit({required double price, Map<String, dynamic>? attrs}) => Listing(
        id: 'u', userId: 'a', categoryId: 'real_estate', countryCode: 'ES',
        title: 't', description: 'd', price: price, images: const [],
        createdAt: DateTime(2026), attributes: attrs,
      );

  void main() {
    test('empty units → empty typologies', () {
      expect(aggregateTypologies([]), isEmpty);
    });
    test('buckets by rooms, min price, m2 range, sorted asc', () {
      final t = aggregateTypologies([
        _unit(price: 200000, attrs: {'rooms': '2', 'm2': '70'}),
        _unit(price: 180000, attrs: {'rooms': '2', 'm2': '65'}),
        _unit(price: 300000, attrs: {'rooms': '3', 'm2': '90'}),
      ]);
      expect(t.length, 2);
      expect(t[0].rooms, 2);
      expect(t[0].count, 2);
      expect(t[0].priceFrom, 180000);
      expect(t[0].m2Min, 65);
      expect(t[0].m2Max, 70);
      expect(t[1].rooms, 3);
    });
    test('units without rooms are skipped', () {
      expect(aggregateTypologies([_unit(price: 1, attrs: {'m2': '50'})]), isEmpty);
      expect(aggregateTypologies([_unit(price: 1, attrs: null)]), isEmpty);
    });
  }
  ```
  NOTE: this test assumes `Listing` has an `attributes` field. It DOES (added
  in Sprint 2 T3 — `Listing.attributes` is a `Map<String,dynamic>?` populated
  by `fromJson`, not serialized in `toJson`/`toInsertJson`). Use it.

- [ ] **Step 2:** Run — expect failure (model + function undefined).
- [ ] **Step 3:** Implement `development_model.dart` (the 3 classes +
  `aggregateTypologies`). `Development.fromRow` parses snake_case:
  `agency_user_id, promoter_name, country_code, delivery_label, created_at`,
  and casts `amenities`/`images` via `(row['amenities'] as List?)?.cast<String>()
  ?? const []`. `latitude`/`longitude` via `(row['latitude'] as num?)?.toDouble()`.
- [ ] **Step 4:** Write `test/development_model_test.dart` (fromRow parses a
  full snake_case row incl. nulls + arrays), run — expect pass after impl.
- [ ] **Step 5:** Run both test files — expect pass.
- [ ] **Step 6:** `flutter analyze` clean; commit
  `feat(developments): Development model + typology aggregation`.

---

### Task 2: DevelopmentsService + providers + lead method

**Files:**
- Create: `lib/features/developments/data/developments_service.dart`
- Modify: `lib/core/services/leads_service.dart`

**Interfaces produced:**
- `class DevelopmentsService { DevelopmentsService(this._supabase); ... }` with:
  - `Future<List<DevelopmentCardData>> fetchDevelopmentsForCountry(String countryCode, {String? city, int limit = 60})`
  - `Future<Development?> fetchDevelopment(String id)`
  - `Future<List<Listing>> fetchDevelopmentUnits(String id)`
- `developmentsServiceProvider` (Provider), `developmentsForCountryProvider`
  (FutureProvider<List<DevelopmentCardData>> — watches `selectedCountryProvider`),
  `developmentDetailProvider` (FutureProvider.family<Development?, String>),
  `developmentUnitsProvider` (FutureProvider.family<List<Listing>, String>).
- `LeadsService.submitDevelopmentLead({required String developmentId,
  required String name, required String email, required String message,
  String? phone, String honeypot = ''})` → `Future<LeadSubmitOutcome>`.

**Query contracts:**
- `fetchDevelopmentsForCountry`: `_supabase.from('developments').select().eq('country_code', countryCode)[.ilike('city', '%$city%')].order('created_at', ascending:false).limit(limit)` → parse rows to `Development`. Then `_supabase.from('listings').select('development_id, price, currency').inFilter('development_id', ids).eq('status','active')` → fold into per-development `priceFrom`(min)/`currency`(first)/`unitCount`. Developments with no units → priceFrom null, currency null, unitCount 0.
- `fetchDevelopment`: `.select().eq('id', id).maybeSingle()` → `Development.fromRow` or null.
- `fetchDevelopmentUnits`: `.from('listings').select().eq('development_id', id).eq('status','active').order('price', ascending:true)` → `Listing.fromJson` per row (with the same `users`/`categories` null-tolerance the search results have — but units don't need the join; a plain select is fine, `Listing.fromJson` tolerates missing user_name).
- `submitDevelopmentLead`: mirror the existing `submitLead` (honeypot short-circuit → `{ok}`, client `validate(...)` → invalidInput, then `_supabase.rpc('submit_development_lead', params: {p_development_id, p_name, p_email, p_phone: phone ?? '', p_message})`, map PostgrestException codes the same way `submitLead` does).

- [ ] **Step 1:** Add `submitDevelopmentLead` to `leads_service.dart` (copy the
  `submitLead` body, swap the RPC name + `p_development_id`). No new test —
  it's exercised by the widget test in T5/T6 and mirrors the tested `submitLead`.
- [ ] **Step 2:** Implement `developments_service.dart` (the 3 methods + the
  4 providers). Read `lib/core/services/listing_service.dart` +
  `lib/core/providers/supabase_provider.dart` for the service/provider idiom,
  and `lib/core/providers/selected_country_provider.dart` for the country.
- [ ] **Step 3:** `flutter analyze` clean; run `flutter test` (no new tests,
  suite must stay green); commit
  `feat(developments): service + providers + development lead`.

---

### Task 3: DevelopmentCard widget + /promociones index screen

**Files:**
- Create: `lib/features/developments/presentation/widgets/development_card.dart`
- Create: `lib/features/developments/presentation/screens/promociones_screen.dart`
- Modify: `lib/core/router/app_router.dart` (route + `AppRoutes.promociones`)
- Modify: `lib/features/listings/presentation/screens/all_categories_screen.dart` (tile)
- Test: `test/promociones_screen_test.dart`

**Interfaces produced:**
- `DevelopmentCard extends StatelessWidget { final DevelopmentCardData development; }` — cover image (first of `images` or 🏠 fallback via `CachedNetworkImage`), name (2-line clamp), city, price line ("Desde {priceFrom €}" or "Precio a consultar"), "{unitCount} viviendas" badge when >0. Tap → `context.push(AppRoutes.promocionDetail(development.id))`.
- `PromocionesScreen extends ConsumerWidget` — watches `developmentsForCountryProvider`, `.when(data/loading/error)`, empty state, 2-col grid of `DevelopmentCard`.

- [ ] **Step 1:** Widget test `test/promociones_screen_test.dart`: a
  `FakeDevelopmentsService extends DevelopmentsService` (override
  `fetchDevelopmentsForCountry`); pump `Promociones Screen` in `ProviderScope`
  (override `developmentsServiceProvider` + `selectedCountryProvider`); assert
  empty state text when `[]`; assert 2 `DevelopmentCard`s when 2 items. (Use
  the same fake-supabase-with-autoRefreshToken:false pattern the Sprint 2
  `valuation_screen_test.dart` used to construct the base service.)
- [ ] **Step 2:** Implement `DevelopmentCard`.
- [ ] **Step 3:** Implement `PromocionesScreen`.
- [ ] **Step 4:** Add the `/promociones` route + `AppRoutes.promociones`; add
  the "Promociones / Obra nueva" tile to `all_categories_screen.dart`.
- [ ] **Step 5:** Run the test — expect pass; `flutter analyze` clean; commit
  `feat(developments): /promociones index + DevelopmentCard`.

---

### Task 4: /promocion/:id detail screen (sections 1-7)

**Files:**
- Create: `lib/features/developments/presentation/screens/promocion_detail_screen.dart`
- Modify: `lib/core/router/app_router.dart` (route + `AppRoutes.promocionDetail(id)`)

**Interface produced:**
- `PromocionDetailScreen extends ConsumerWidget { final String developmentId; }`
  — watches `developmentDetailProvider(id)` + `developmentUnitsProvider(id)`;
  renders hero, gallery, description, amenities, location (+ "Abrir en mapas"
  via url_launcher when coords are finite & non-zero), typology table
  (`aggregateTypologies(units)`), units grid (`ListingCard`, tap →
  `/listing/:id`). Section 8 (contact) is added in T5.
- Status badge labels: `planning` → "En planos", `building` → "En
  construcción", `ready` → "Lista para entrar".
- `AppRoutes.promocionDetail(String id) => '/promocion/$id'`.

- [ ] **Step 1:** Implement the screen (sections 1-7). Use `AppColors.primary`
  for the app bar; `CachedNetworkImage` for gallery; `ListingCard` for units
  grid; a `Table` or column of rows for the typology table. The "Abrir en
  mapas" button uses `launchUrl(Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng'), mode: LaunchMode.externalApplication)`.
- [ ] **Step 2:** Add the `/promocion/:id` route (reads `state.pathParameters['id']!`)
  + `AppRoutes.promocionDetail`.
- [ ] **Step 3:** `flutter analyze` clean; commit
  `feat(developments): /promocion/:id detail screen`.

---

### Task 5: Development contact sheet (lead capture, section 8)

**Files:**
- Create: `lib/features/developments/presentation/widgets/development_contact_sheet.dart`
- Modify: `lib/features/developments/presentation/screens/promocion_detail_screen.dart`

**Interface produced:**
- `Future<void> showDevelopmentContactSheet(BuildContext, WidgetRef, Development)`
  — a modal bottom sheet mirroring the listing `contact_sheet.dart` (name,
  email, phone optional, message, HIDDEN honeypot field), calling
  `ref.read(leadsServiceProvider).submitDevelopmentLead(developmentId: dev.id,
  ...)`. Success → pop + "Mensaje enviado a la promotora." SnackBar; error →
  a Spanish error SnackBar mapped from `LeadSubmitError`. NOT auth-gated (the
  RPC is anon-callable; the honeypot + validation guard it) — but prefill
  name/email from the signed-in profile when available (like the listing sheet).
- The detail screen adds a "Contactar con la promotora" button (section 8)
  that opens the sheet.

- [ ] **Step 1:** Implement the contact sheet (copy the structure of
  `lib/features/listings/presentation/widgets/contact_sheet.dart`, swap the
  service call to `submitDevelopmentLead`, drop the listing-title prefill and
  use the development name in the default message).
- [ ] **Step 2:** Wire the "Contactar con la promotora" button into the
  detail screen.
- [ ] **Step 3:** `flutter analyze` clean; commit
  `feat(developments): development lead contact sheet`.

---

### Task 6: Final verification

- [ ] **Step 1:** `flutter test` — full suite green (existing 35 + new
  typology/model/promociones tests).
- [ ] **Step 2:** `flutter analyze` — 0 errors.
- [ ] **Step 3:** `flutter build apk --debug --no-pub` — succeeds (run in
  foreground; slow, several minutes).
- [ ] **Step 4:** Commit
  `chore(developments): sprint 3 verification (analyze + tests + APK build)`.

---

## Final whole-branch review (Task 7)

Dispatch the most-capable reviewer over merge-base..HEAD. Lens:
- The 2 public screens (index + detail) match the web's structure.
- `aggregateTypologies` matches the web's bucketing (min price, m2 range,
  skip untyped units, sort asc).
- `submitDevelopmentLead` uses the `submit_development_lead` RPC with
  `p_development_id`, honeypot + validation identical to `submitLead`.
- The lead sheet is NOT auth-gated (matches the anon-callable RPC) — verify no
  accidental `currentUser!` crash path (the service doesn't need the user).
- No new dependencies; `path_provider_android` pin intact; the map is a
  `url_launcher` button, not a new map package.
- `ListingCard` reused for units (tap → `/listing/:id`).
- No cross-user gaps: developments + units reads are public/active-only.
- `flutter analyze` 0 errors; `flutter test` green; APK build OK.

## Verification (post Task 6)

```bash
cd app_flutter
flutter analyze && flutter test && flutter build apk --debug --no-pub
```

Manual smoke: open `/promociones` → see the country's developments → tap one →
see hero/gallery/amenities/typology/units → "Contactar con la promotora" →
fill + send → success SnackBar.

## Self-review

- Spec coverage: D1 (service) = T2, D2 (lead) = T2 + T5, D3 (index) = T3,
  D4 (detail) = T4 + T5. Model + typology = T1. ✓
- No placeholders; each step has code or an exact change. ✓
- Type consistency: `Development`/`DevelopmentCardData`/`Typology` (T1)
  consumed by the service (T2), the card + screens (T3-T5), and the tests. ✓
