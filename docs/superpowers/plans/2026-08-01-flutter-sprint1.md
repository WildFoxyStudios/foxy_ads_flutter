# Flutter Sprint 1 — Core Marketplace Completeness — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add edit-listing and saved-searches to the Flutter app, reaching
parity with the web app's core individual-seller/buyer loop.

**Architecture:** Riverpod 3 + go_router + Supabase, `core/` + `features/`
layers. Refactor the existing `CreateListingScreen` into a create-or-edit form
(no duplication). Saved searches write directly to `public.saved_searches`
under RLS (no RPC), mirroring the web.

**Tech Stack:** Flutter 3.44 / Dart 3.12, flutter_riverpod ^3, go_router ^17,
supabase_flutter ^2, image_picker ^1, flutter_test.

## Global Constraints

- No new dependencies (pubspec unchanged except if a dev-only test helper is
  needed — avoid if possible).
- `path_provider_android` stays pinned to `2.2.23` in `dependency_overrides`
  (removing it re-breaks the JNI build).
- `flutter analyze` must report **0 errors** after every task (deprecation
  `info`s are acceptable and pre-existing).
- `flutter build apk --debug --no-pub` must succeed after the final task.
- All Supabase writes rely on existing RLS (`user_id = auth.uid()`); never use
  a service-role key in the client.
- The create-listing path must remain behavior-identical when `existing == null`
  (the edit refactor is strictly additive behind that null check).
- Spanish-only UI strings (i18n is a later sprint); match the existing copy
  style.
- Owner-only actions (edit) are gated client-side AND rely on RLS server-side.

---

## Prerequisite (controller, before Task 1)

Initialize a git repo in `app_flutter/` so the SDD review-package flow works
and the Flutter app gains version control:

```bash
cd app_flutter
git init
printf '\nbuild/\n.dart_tool/\n.flutter-plugins-dependencies\n' >> .gitignore   # if not already ignored
git add -A && git commit -m "chore: baseline before Sprint 1 (edit + saved searches)"
```

The `.env` file (live Supabase keys) is already git-ignored via the existing
`.gitignore`; verify `git status` does not list `.env` before the baseline
commit.

---

## File Structure

### Create
- `lib/core/models/saved_search_model.dart` — typed `saved_searches` row +
  the serialized-filter payload.
- `lib/core/services/saved_searches_service.dart` — list/create/delete/touchSeen.
- `lib/features/search/presentation/providers/saved_searches_provider.dart` —
  `savedSearchesProvider` + invalidation.
- `lib/features/search/presentation/screens/saved_searches_screen.dart` — list
  + delete + re-run.
- `test/search_filters_serialization_test.dart` — `SearchFilters` round-trip.
- `test/saved_search_model_test.dart` — model (de)serialization.

### Modify
- `lib/features/search/presentation/providers/search_filters_provider.dart` —
  add `SearchFilters.toJson()` / `SearchFilters.fromJson()`.
- `lib/features/listings/presentation/screens/create_listing_screen.dart` —
  optional `Listing? existing`; prefill; two image lists; update-on-submit.
- `lib/core/router/app_router.dart` — add `/edit-listing/:id`.
- `lib/features/profile/presentation/screens/my_listings_screen.dart` — "Editar"
  action per row.
- `lib/features/listings/presentation/screens/listing_detail_screen.dart` —
  owner-only "Editar" entry in the existing `PopupMenuButton`.
- `lib/features/search/presentation/screens/search_screen.dart` — "Guardar
  búsqueda" button when filters are active.
- `lib/features/profile/presentation/screens/profile_screen.dart` — "Búsquedas
  guardadas" tile → `/saved-searches`.

### Delete
- None.

---

## Task Decomposition

6 implementation tasks. Each ends with `flutter analyze` clean and one commit.

### Task 1: SearchFilters (de)serialization

**Files:**
- Modify: `lib/features/search/presentation/providers/search_filters_provider.dart`
- Test: `test/search_filters_serialization_test.dart`

**Interfaces produced:**
- `Map<String, dynamic> SearchFilters.toJson()` — emits
  `{query, categoryId, minPrice, maxPrice, sort}` (nulls omitted or kept
  consistently).
- `factory SearchFilters.fromJson(Map<String, dynamic>)` — inverse; tolerant of
  missing keys (defaults: query `''`, sort `'newest'`, others null).

- [ ] **Step 1: Write the failing test**

```dart
// test/search_filters_serialization_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:foxy_ads/features/search/presentation/providers/search_filters_provider.dart';

void main() {
  test('SearchFilters round-trips through JSON', () {
    const f = SearchFilters(
      query: 'piso madrid',
      categoryId: 'real_estate',
      minPrice: 100,
      maxPrice: 500000,
      sort: 'price_asc',
    );
    final restored = SearchFilters.fromJson(f.toJson());
    expect(restored, f);
  });

  test('fromJson tolerates missing keys with defaults', () {
    final f = SearchFilters.fromJson(const {});
    expect(f.query, '');
    expect(f.sort, 'newest');
    expect(f.categoryId, isNull);
    expect(f.minPrice, isNull);
    expect(f.maxPrice, isNull);
  });
}
```

- [ ] **Step 2: Run it — expect failure** (`toJson`/`fromJson` undefined).

Run: `flutter test test/search_filters_serialization_test.dart`
Expected: compile error / FAIL.

- [ ] **Step 3: Implement `toJson`/`fromJson` on `SearchFilters`.**

```dart
  Map<String, dynamic> toJson() => {
        'query': query,
        'categoryId': categoryId,
        'minPrice': minPrice,
        'maxPrice': maxPrice,
        'sort': sort,
      };

  factory SearchFilters.fromJson(Map<String, dynamic> json) => SearchFilters(
        query: (json['query'] as String?) ?? '',
        categoryId: json['categoryId'] as String?,
        minPrice: (json['minPrice'] as num?)?.toDouble(),
        maxPrice: (json['maxPrice'] as num?)?.toDouble(),
        sort: (json['sort'] as String?) ?? 'newest',
      );
```

- [ ] **Step 4: Run the test — expect PASS.**
- [ ] **Step 5: `flutter analyze` clean; commit** `feat(search): serialize SearchFilters to/from JSON`.

---

### Task 2: SavedSearch model + service + provider

**Files:**
- Create: `lib/core/models/saved_search_model.dart`
- Create: `lib/core/services/saved_searches_service.dart`
- Create: `lib/features/search/presentation/providers/saved_searches_provider.dart`
- Test: `test/saved_search_model_test.dart`

**Interfaces consumed:** `SearchFilters.toJson/fromJson` (Task 1).

**Interfaces produced:**
- `class SavedSearch { String id; String userId; String? categoryId; String? label; SearchFilters filters; String? countryCode; DateTime createdAt; DateTime? lastSeenAt; }`
  with `factory SavedSearch.fromRow(Map<String,dynamic>)` (parses the `query`
  column, a JSON string, into `filters` via `SearchFilters.fromJson`).
- `SavedSearchesService`:
  - `Future<List<SavedSearch>> list()`
  - `Future<SavedSearch> create({required String label, required SearchFilters filters, String? countryCode, String? categoryId})`
  - `Future<void> delete(String id)`
  - `Future<void> touchSeen(String id)`
- `savedSearchesServiceProvider` (Provider) and
  `savedSearchesProvider` (FutureProvider<List<SavedSearch>>).

**Row contract:** the `query` column stores `jsonEncode(filters.toJson())`.
`label`, `category_id`, `country_code` are stored as their own columns.
`user_id` comes from `_supabase.auth.currentUser!.id`.

- [ ] **Step 1: Write the failing test** for `SavedSearch.fromRow` — given a
  row with `query` = a JSON string, it parses `filters` correctly and reads
  the scalar columns.

```dart
// test/saved_search_model_test.dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxy_ads/core/models/saved_search_model.dart';

void main() {
  test('SavedSearch.fromRow parses the query JSON into filters', () {
    final row = {
      'id': 'abc',
      'user_id': 'u1',
      'category_id': 'vehicles',
      'label': 'Coches Madrid',
      'query': jsonEncode({'query': 'coche', 'sort': 'newest'}),
      'country_code': 'ES',
      'created_at': '2026-08-01T00:00:00Z',
      'last_seen_at': null,
    };
    final s = SavedSearch.fromRow(row);
    expect(s.id, 'abc');
    expect(s.label, 'Coches Madrid');
    expect(s.filters.query, 'coche');
    expect(s.countryCode, 'ES');
    expect(s.lastSeenAt, isNull);
  });
}
```

- [ ] **Step 2: Run — expect FAIL** (model undefined).
- [ ] **Step 3: Implement** `SavedSearch` model, then `SavedSearchesService`
  (using `_supabase.from('saved_searches')` — `.select().order('created_at',
  ascending:false)`, `.insert(...).select().single()`, `.delete().eq('id',id)`,
  `.update({'last_seen_at': now}).eq('id',id)`), then the providers.
- [ ] **Step 4: Run the model test — expect PASS.**
- [ ] **Step 5: `flutter analyze` clean; commit** `feat(saved-searches): model + service + provider`.

---

### Task 3: Saved searches UI (save button, list screen, profile tile)

**Files:**
- Create: `lib/features/search/presentation/screens/saved_searches_screen.dart`
- Modify: `lib/features/search/presentation/screens/search_screen.dart`
- Modify: `lib/features/profile/presentation/screens/profile_screen.dart`
- Modify: `lib/core/router/app_router.dart` (add `/saved-searches`)

**Interfaces consumed:** `savedSearchesProvider`, `SavedSearchesService`,
`searchFiltersProvider`, `authStateProvider`.

- [ ] **Step 1: Add the `/saved-searches` route** in `app_router.dart`
  (`name: 'savedSearches'`, builder → `const SavedSearchesScreen()`), plus
  `AppRoutes.savedSearches = '/saved-searches'`.
- [ ] **Step 2: Build `SavedSearchesScreen`** — `ConsumerWidget` watching
  `savedSearchesProvider`; `ListView` of cards (label + filter summary +
  delete icon); empty state; tap → set `searchFiltersProvider` from
  `s.filters`, call `touchSeen(s.id)`, `context.go('/search')`; delete →
  confirm dialog → `service.delete(id)` → `ref.invalidate(savedSearchesProvider)`.
- [ ] **Step 3: Add "Guardar búsqueda" button** to `search_screen.dart`
  (bookmark `IconButton` next to the filter `IconButton`, visible when
  `filters.isActive`). On tap: if `authStateProvider.value == null` →
  `context.push('/login')`; else generate a label
  (`filters.query.isNotEmpty ? filters.query : '<category> · <country>'`),
  `await service.create(label: ..., filters: filters, countryCode: country.code,
  categoryId: filters.categoryId)`, `ref.invalidate(savedSearchesProvider)`,
  show a confirmation `SnackBar`.
- [ ] **Step 4: Add "Búsquedas guardadas" tile** to `profile_screen.dart`
  (a `ListTile` with a bookmark icon → `context.push('/saved-searches')`),
  placed with the other profile navigation tiles.
- [ ] **Step 5: `flutter analyze` clean; commit** `feat(saved-searches): save button, list screen, profile entry`.

---

### Task 4: Edit listing — refactor CreateListingScreen to create-or-edit

**Files:**
- Modify: `lib/features/listings/presentation/screens/create_listing_screen.dart`

**Interfaces produced:**
- `CreateListingScreen({Key? key, Listing? existing})` — `existing == null` →
  create (unchanged behavior); non-null → edit.

- [ ] **Step 1:** Add `final Listing? existing;` to the widget + constructor.
- [ ] **Step 2:** In `initState`, when `existing != null`, prefill every
  controller (`title`, `description`, `price`, `whatsapp`, `phone`, `email`,
  `city`), the selected category/subcategory, country, currency, and
  `is_negotiable`. Seed `List<String> _existingImageUrls = existing.images`.
- [ ] **Step 3:** Render existing image URLs (network thumbnails with a remove
  ✕) alongside the picked-`XFile` thumbnails. Keep the "add images" tile.
  Enforce `_existingImageUrls.length + _newImages.length <= 10`.
- [ ] **Step 4:** Switch AppBar title to `existing == null ? 'Publicar anuncio'
  : 'Editar anuncio'` and the submit button label to `'Guardar cambios'` in
  edit mode.
- [ ] **Step 5:** In `_submitListing`, when editing: upload `_newImages`, build
  `updates` (same field map minus `user_id`, with
  `images: [..._existingImageUrls, ...newUrls]`), call
  `listingService.updateListing(existing!.id, updates)`; on success pop and
  show a "Cambios guardados" SnackBar. Creation path unchanged.
- [ ] **Step 6: `flutter analyze` clean; commit** `feat(listings): edit existing listing (create-or-edit form)`.

---

### Task 5: Edit entry points + owner guard

**Files:**
- Modify: `lib/core/router/app_router.dart` (add `/edit-listing/:id`)
- Modify: `lib/features/profile/presentation/screens/my_listings_screen.dart`
- Modify: `lib/features/listings/presentation/screens/listing_detail_screen.dart`

**Interfaces consumed:** `CreateListingScreen(existing:)`, `listingDetailProvider`,
`authStateProvider`.

- [ ] **Step 1:** Add `/edit-listing/:id` route: a small `ConsumerWidget` that
  watches `listingDetailProvider(id)`; while loading → spinner; on data → if
  `listing == null` or `listing.userId != currentUser?.id` →
  `Scaffold(body: Center(child: Text('No autorizado')))` (defense-in-depth);
  else `CreateListingScreen(existing: listing)`. Add
  `AppRoutes.editListing(String id) => '/edit-listing/$id'`.
- [ ] **Step 2:** In `my_listings_screen.dart`, add an "Editar" action (icon or
  menu item) on each row → `context.push(AppRoutes.editListing(listing.id))`.
- [ ] **Step 3:** In `listing_detail_screen.dart`, add an "Editar" entry to the
  existing `PopupMenuButton` (value `'edit'`), shown ONLY when
  `authState.value?.id == listing.userId`; on select →
  `context.push(AppRoutes.editListing(listing.id))`.
- [ ] **Step 4: `flutter analyze` clean; commit** `feat(listings): edit entry points + owner guard`.

---

### Task 6: Form-mode widget test + final verification

**Files:**
- Create: `test/listing_form_mode_test.dart`

- [ ] **Step 1:** Widget test: pump `CreateListingScreen()` (no `existing`) →
  expect the AppBar shows the create title and the submit button shows the
  create label. Pump `CreateListingScreen(existing: fakeListing)` → expect the
  edit title, the "Guardar cambios" button, and the title field prefilled with
  `fakeListing.title`. (Wrap in `ProviderScope` + `MaterialApp`; override any
  providers the screen reads at build time, e.g. `createListingCategoriesProvider`
  with an `AsyncValue.data([])`, and Supabase-backed providers as needed so the
  screen builds without network.)
- [ ] **Step 2: Run** `flutter test` — all tests pass.
- [ ] **Step 3: Run** `flutter analyze` — 0 errors.
- [ ] **Step 4: Run** `flutter build apk --debug --no-pub` — succeeds.
- [ ] **Step 5: Commit** `test(listings): create-vs-edit form mode + sprint 1 verification`.

---

## Verification

```bash
cd app_flutter
flutter analyze            # 0 errors
flutter test               # all green
flutter build apk --debug --no-pub   # builds
```

Manual smoke: create a listing → edit it (change title + swap an image) →
run a search with filters → "Guardar búsqueda" → open Profile → "Búsquedas
guardadas" → tap to re-run → delete it.

## Self-review notes

- Spec coverage: edit listing (Tasks 4–5), saved searches (Tasks 1–3), image
  polish folded into Task 4 + Task 6. ✓
- No placeholders; every code step shows the code or the exact change. ✓
- Type consistency: `SearchFilters.toJson/fromJson` (Task 1) is consumed by
  `SavedSearch.fromRow` and the service (Task 2) and the UI (Task 3). ✓
