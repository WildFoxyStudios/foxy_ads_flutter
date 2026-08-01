# Flutter Sprint 1 — Core Marketplace Completeness (Design)

**Date:** 2026-08-01
**Status:** Approved (verbal)
**Scope:** Bring the Flutter app's core marketplace loop to parity with the web
app for the *individual seller/buyer* flows. Part 1 of a 4-sprint parity effort
(Sprint 2 real-estate vertical, Sprint 3 promotions, Sprint 4 agency/B2B).
Admin panel (`admin-foxy`) is explicitly OUT of scope for all Flutter work.

## Goal

Close the three most-used gaps in the core listing lifecycle:
1. **Edit an existing listing** (today the app can only create).
2. **Save a search** and re-run it later.
3. Minor polish on the (already-working) image upload flow.

## Architecture

Reuse the established stack — Riverpod 3 + go_router + Supabase (`core/` +
`features/` layers). No new dependencies. All writes go through the existing
RLS policies (Supabase enforces `user_id = auth.uid()`), same as the web app.

## Deliverable 1 — Edit listing

**Approach:** refactor `CreateListingScreen` into a *create-or-edit* screen
rather than duplicating a 597-line form.

- `CreateListingScreen` gains an optional `final Listing? existing;`
  constructor param. When non-null:
  - All text controllers are prefilled from `existing` in `initState`.
  - Category/subcategory, country, city, price, currency, contact fields,
    `is_negotiable`, and existing image URLs are prefilled.
  - Already-uploaded images render from their URLs (network) with a remove
    affordance; newly-picked `XFile`s are appended and uploaded on submit.
  - The AppBar title switches to "Editar anuncio" and the submit button to
    "Guardar cambios".
  - `_submitListing` calls `listingService.updateListing(existing.id, updates)`
    instead of `createListing`. `updates` is the same field map the insert
    builds, minus `user_id` (never changed) and including the merged
    `images` list (kept URLs + newly-uploaded URLs).
- New route: `GoRoute(path: '/edit-listing/:id', ...)` that loads the listing
  via `listingDetailProvider(id)` and passes it as `existing`. If the loaded
  listing's `user_id != currentUser.id`, redirect away (defense-in-depth; RLS
  already blocks the update).
- Entry points:
  - `MyListingsScreen`: an "Editar" action on each of the user's listing rows.
  - `ListingDetailScreen`: an "Editar" entry in the existing overflow
    (`PopupMenuButton`) — shown ONLY when the viewer owns the listing.

**Image handling on edit:** the form holds two lists — `List<String>
_existingImageUrls` (already uploaded) and `List<XFile> _newImages` (to
upload). On submit: upload the new ones, then `images = [..._existingImageUrls,
...uploadedNewUrls]` capped at 10. Removing an existing image just drops its
URL from `_existingImageUrls` (the storage object is left as-is — orphan
cleanup is out of scope, matches web behavior).

## Deliverable 2 — Saved searches

Table `public.saved_searches` already exists:
`id, user_id, category_id, label, query, country_code, created_at, last_seen_at`.
No RPC — the web writes directly under RLS; Flutter does the same.

- `SavedSearchesModel` (`core/models/saved_search_model.dart`): typed row.
  The `query` column stores a JSON string of the serialized filter set
  (`{query, categoryId, minPrice, maxPrice, sort}`) so the whole filter can be
  round-tripped.
- `SavedSearchesService` (`core/services/saved_searches_service.dart`):
  - `list()` → the caller's saved searches, newest first.
  - `create({label, filters, countryCode, categoryId})` → insert (user_id from
    `auth.currentUser`).
  - `delete(id)` → delete own row.
  - `touchSeen(id)` → set `last_seen_at = now()` (used when re-running; keeps
    the "new since last seen" semantics available for a future alerts feature).
- A Riverpod `savedSearchesProvider` (FutureProvider) + a notifier to
  invalidate after create/delete.
- **Search screen:** a "Guardar búsqueda" button (bookmark icon) visible when
  `filters.isActive`. Tapping it generates a human label (e.g. the query text,
  or "Categoría · País" when no query) and calls `create`. Requires auth →
  routes to `/login` if signed out.
- **Saved searches list screen** (`features/search/.../saved_searches_screen.dart`),
  reached from a "Búsquedas guardadas" tile in the Profile screen:
  - Lists saved searches with label + a subtitle summarizing the filters.
  - Tap → deserialize the filters into `searchFiltersProvider`, `touchSeen`,
    and navigate to `/search`.
  - Swipe-to-delete (or a delete icon) with a confirm.
- **Alerts / push notifications: DEFERRED** — needs FCM infrastructure; the
  `last_seen_at` column is populated so alerts can be added later without a
  schema change.

## Deliverable 3 — Image upload polish (minor)

The upload already works (`image_picker.pickMultiImage` → `uploadImages` →
`supabase.storage.from('listings').uploadBinary`, capped at 10, per-item
remove). Only additions:
- Show a progress indicator while `uploadImages` runs on submit (the submit
  button already has a spinner; ensure it covers the upload phase).
- No drag-reorder in this sprint (nice-to-have, deferred).

This deliverable folds into Deliverable 1's testing (the edit flow exercises
the same image widgets).

## Testing

- Widget test: the shared form in create mode (empty) vs edit mode (prefilled
  from a fake `Listing`) renders the right title/button and prefilled values.
- Widget/unit test: `SavedSearchesService.create/list/delete` against a fake
  Supabase client (or a thin seam), and the filter (de)serialization round-trip.
- Manual: `flutter analyze` clean (0 errors), `flutter build apk --debug`
  succeeds, and a manual pass of create → edit → save-search → re-run → delete.

## Out of scope (this sprint)

- Search alerts / push notifications (deferred; schema already supports it).
- Drag-reorder of images.
- Storage orphan cleanup on image removal.
- Everything in Sprints 2–4 (real-estate vertical, promotions, agency/B2B),
  i18n, and static pages.

## Risks

- **Refactoring the working create screen** could regress creation. Mitigation:
  the create path stays the default (`existing == null`); all edit behavior is
  behind that null check; a widget test pins both modes.
- **Filter serialization drift** between save and re-run. Mitigation: a single
  `SearchFilters.toJson()/fromJson()` pair used by both sides, unit-tested for
  round-trip.
