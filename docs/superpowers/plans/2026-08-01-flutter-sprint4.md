# Flutter Sprint 4 — Agency / B2B Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port the full web B2B/agency surface to Flutter — public agency
profile, editable agency profile (with logo), and a Pro Dashboard bundling
Stats, a views chart, a CRM leads inbox, developments CRUD + assign, bulk
listing ops, and CSV export — all client-side under RLS.

**Architecture:** New `lib/features/agency/` module + extensions to the existing
`developments/`, `leads_service.dart`, and `listing_service.dart`. Riverpod 3 +
go_router + Supabase. The verified-agency check is a client product gate; RLS
ownership is the real boundary. No service-role key in the client.

**Tech Stack:** Flutter 3.44 / Dart 3.12, flutter_riverpod ^3, go_router ^17,
supabase_flutter ^2, cached_network_image ^3, image_picker ^1, url_launcher ^6,
share_plus (already present).

## Global Constraints

- No new dependencies. Views chart = `CustomPainter`; CSV export shares via the
  already-present `SharePlus`.
- All reads/writes go through the signed-in user's Supabase session under RLS.
  NO service-role key. Every mutating service method additionally filters by the
  caller's `user_id`/`agency_user_id` (defense in depth).
- `upsertAgencyProfile` NEVER writes `is_verified` (admin-only; DB trigger
  `agency_profiles_protect_verified` also blocks it).
- Validation bounds are parity-locked against the web source of truth
  (`src/lib/agency.ts`, `src/lib/leads.ts`, `src/lib/developments.ts`,
  `src/app/actions/panel.ts`). Values in this plan are the exact contract.
- Lead statuses: `new | contacted | closed`. Development statuses:
  `planning | building | ready`. Stored strings verbatim.
- `flutter analyze` 0 errors after every task (pre-existing infos OK).
- `flutter test` full suite green after every task. Do NOT run `flutter build
  apk` inside tasks (the controller runs it once at phase boundaries / final).
- Spanish-only UI strings (matching the app today). No i18n.
- Reuse existing pieces: `ListingCard`, `AppColors`, `authStateProvider`/
  `currentUserProvider` (`lib/core/services/auth_service.dart`),
  `supabaseClientProvider`, `selectedCountryProvider`, the Sprint-3
  `Development`/`developmentDetailProvider`, and `ListingService.uploadImages`
  (the storage upload path).

---

## File Structure

**Create**
- `lib/features/agency/data/agency_model.dart` — `AgencyProfile`, `AgencyInput`, `validateAgencyInput`, `AgencyValidationError`.
- `lib/features/agency/data/lead_model.dart` — `Lead`, `LEAD_STATUSES`, `LeadStatus`.
- `lib/features/agency/data/agency_service.dart` — `AgencyService` + agency providers.
- `lib/features/agency/data/panel_stats.dart` — pure `computePanelStats(...)` + `PanelStats`, `DayPoint`.
- `lib/features/agency/presentation/screens/agency_profile_screen.dart` — public `/agencia/:id`.
- `lib/features/agency/presentation/screens/agency_profile_edit_screen.dart` — `/agencia/editar`.
- `lib/features/agency/presentation/screens/panel_screen.dart` — `/panel` gate + shell.
- `lib/features/agency/presentation/widgets/agency_verified_badge.dart` — verified chip.
- `lib/features/agency/presentation/widgets/panel_stats_cards.dart` — 6 stat tiles.
- `lib/features/agency/presentation/widgets/panel_views_chart.dart` — CustomPainter chart.
- `lib/features/agency/presentation/widgets/leads_panel.dart` — CRM section.
- `lib/features/agency/presentation/widgets/developments_panel.dart` — dev list + actions.
- `lib/features/agency/presentation/widgets/bulk_listings_panel.dart` — bulk ops section.
- `lib/features/developments/presentation/screens/development_form_screen.dart` — create/edit.
- Tests: `test/agency_validation_test.dart`, `test/panel_pure_test.dart`, `test/panel_stats_test.dart`, `test/agency_profile_screen_test.dart`, `test/panel_gate_test.dart`, `test/leads_panel_test.dart`.

**Modify**
- `lib/core/services/leads_service.dart` — add `listAgencyLeads`, `updateLeadStatus`, `updateLeadNotes`, `LeadActionOutcome`, lead providers.
- `lib/features/developments/data/development_model.dart` — add `DEVELOPMENT_STATUSES`, `DevelopmentInput`, `validateDevelopmentInput`.
- `lib/features/developments/data/developments_service.dart` — add CRUD + `assignListingsToDevelopment` + `uploadDevelopmentImages` + `myDevelopmentsProvider` + `DevActionOutcome`.
- `lib/core/services/listing_service.dart` — add `parseIds`, `applyPriceMode`, `bulkSetStatus/Delete/Renew/SetPrice`, `getAgencyViewsSeries`, `listingsToCsv`, `PanelActionOutcome`.
- `lib/core/router/app_router.dart` — routes + `AppRoutes` entries.
- `lib/features/profile/presentation/screens/profile_screen.dart` — "Panel Pro" tile (verified only).
- The listing detail screen — "Ver agencia" link when the seller has an agency profile.

---

## Interfaces (produced in T1, consumed throughout)

```dart
// agency_model.dart
class AgencyProfile {
  final String userId, name, createdAt;
  final String? logoUrl, description, website, phone, location;
  final bool isVerified;
  const AgencyProfile({required this.userId, required this.name,
    required this.createdAt, this.logoUrl, this.description, this.website,
    this.phone, this.location, required this.isVerified});
  factory AgencyProfile.fromRow(Map<String, dynamic> r);
}
class AgencyInput {
  final String name;
  final String? logoUrl, description, website, phone, location;
  const AgencyInput({required this.name, this.logoUrl, this.description,
    this.website, this.phone, this.location});
  Map<String, dynamic> toColumns(); // trims; keys: name, logo_url, description, website, phone, location
}
enum AgencyValidationError { name, website, length }
AgencyValidationError? validateAgencyInput(AgencyInput input);

// lead_model.dart
const List<String> LEAD_STATUSES = ['new', 'contacted', 'closed'];
class Lead {
  final String id, listingTitle, ownerUserId, buyerName, buyerEmail,
    message, status, createdAt, updatedAt;
  final String? listingId, developmentId, buyerUserId, buyerPhone, notes;
  const Lead({...});
  factory Lead.fromRow(Map<String, dynamic> r);
}

// development_model.dart (added)
const List<String> DEVELOPMENT_STATUSES = ['planning', 'building', 'ready'];
class DevelopmentInput {
  final String name, countryCode;
  final String? description, promoterName, city, address, deliveryLabel, status;
  final double? latitude, longitude;
  final List<String> amenities, images;
  const DevelopmentInput({...});
  Map<String, dynamic> toColumns(); // snake_case, status ?? 'planning', excludes id/agency_user_id
}
enum DevelopmentValidationError { name, country, status, description, length }
DevelopmentValidationError? validateDevelopmentInput(DevelopmentInput input);

// listing_service.dart (added, pure)
List<String>? parseIds(List<String> ids);           // 1..100, UUID-shaped, dedup lowercase, else null
double applyPriceMode(double current, String mode, double value); // 'set'|'pct', clamp>=0, round2

// panel_stats.dart
class DayPoint { final String day; final int views; const DayPoint(this.day, this.views); }
class PanelStats { final int total, active, sold, views, featured, favorites; const PanelStats({...}); }
PanelStats computePanelStats(List<Listing> rows, Map<String,int> favByListing, DateTime now);

// outcome types (mirror web result unions)
enum AgencyActionError { unauthenticated, forbidden, invalidInput, databaseError }
class LeadActionOutcome { final bool ok; final AgencyActionError? error; ... }
class DevActionOutcome<T> { final bool ok; final AgencyActionError? error; final T? data; ... }
class PanelActionOutcome { final bool ok; final AgencyActionError? error; ... }
```

---

## Task 1: Models + validation + pure panel helpers

**Files:**
- Create: `lib/features/agency/data/agency_model.dart`
- Create: `lib/features/agency/data/lead_model.dart`
- Create: `lib/features/agency/data/panel_stats.dart`
- Modify: `lib/features/developments/data/development_model.dart`
- Modify: `lib/core/services/listing_service.dart` (add `parseIds` + `applyPriceMode` only)
- Test: `test/agency_validation_test.dart`, `test/panel_pure_test.dart`, `test/panel_stats_test.dart`

**Interfaces:** Produces everything in the Interfaces block above.

- [ ] **Step 1: Write the failing validation + pure tests.**

```dart
// test/agency_validation_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:foxy_ads/features/agency/data/agency_model.dart';
import 'package:foxy_ads/features/developments/data/development_model.dart';

void main() {
  group('validateAgencyInput', () {
    test('accepts a minimal valid input', () {
      expect(validateAgencyInput(const AgencyInput(name: 'Ab')), isNull);
    });
    test('rejects short/long name', () {
      expect(validateAgencyInput(const AgencyInput(name: 'A')), AgencyValidationError.name);
      expect(validateAgencyInput(AgencyInput(name: 'x' * 121)), AgencyValidationError.name);
    });
    test('rejects non-http website, accepts https', () {
      expect(validateAgencyInput(const AgencyInput(name: 'Ab', website: 'foo.com')),
          AgencyValidationError.website);
      expect(validateAgencyInput(const AgencyInput(name: 'Ab', website: 'https://foo.com')), isNull);
    });
    test('rejects over-length fields', () {
      expect(validateAgencyInput(AgencyInput(name: 'Ab', website: 'https://${'a' * 300}')),
          AgencyValidationError.length);
      expect(validateAgencyInput(AgencyInput(name: 'Ab', description: 'd' * 2001)),
          AgencyValidationError.length);
      expect(validateAgencyInput(AgencyInput(name: 'Ab', location: 'l' * 201)),
          AgencyValidationError.length);
      expect(validateAgencyInput(AgencyInput(name: 'Ab', phone: '9' * 41)),
          AgencyValidationError.length);
    });
  });

  group('validateDevelopmentInput', () {
    test('accepts minimal valid', () {
      expect(validateDevelopmentInput(const DevelopmentInput(name: 'Ab', countryCode: 'ES')), isNull);
    });
    test('name bounds 2..140', () {
      expect(validateDevelopmentInput(const DevelopmentInput(name: 'A', countryCode: 'ES')),
          DevelopmentValidationError.name);
      expect(validateDevelopmentInput(DevelopmentInput(name: 'x' * 141, countryCode: 'ES')),
          DevelopmentValidationError.name);
    });
    test('country 2..5', () {
      expect(validateDevelopmentInput(const DevelopmentInput(name: 'Ab', countryCode: 'E')),
          DevelopmentValidationError.country);
      expect(validateDevelopmentInput(const DevelopmentInput(name: 'Ab', countryCode: 'ESPAÑA')),
          DevelopmentValidationError.country);
    });
    test('status must be known', () {
      expect(validateDevelopmentInput(const DevelopmentInput(name: 'Ab', countryCode: 'ES', status: 'x')),
          DevelopmentValidationError.status);
      expect(validateDevelopmentInput(const DevelopmentInput(name: 'Ab', countryCode: 'ES', status: 'ready')),
          isNull);
    });
    test('length caps', () {
      expect(validateDevelopmentInput(DevelopmentInput(name: 'Ab', countryCode: 'ES', description: 'd' * 5001)),
          DevelopmentValidationError.description);
      expect(validateDevelopmentInput(DevelopmentInput(name: 'Ab', countryCode: 'ES', city: 'c' * 121)),
          DevelopmentValidationError.length);
    });
  });
}
```

```dart
// test/panel_pure_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:foxy_ads/core/services/listing_service.dart';

const _u = '11111111-1111-1111-1111-111111111111';
const _v = '22222222-2222-2222-2222-222222222222';

void main() {
  group('parseIds', () {
    test('accepts 1..100 unique uuids, dedups case-insensitively', () {
      expect(parseIds([_u]), [_u]);
      expect(parseIds([_u, _u.toUpperCase()])!.length, 1);
    });
    test('rejects empty / >100 / non-uuid', () {
      expect(parseIds([]), isNull);
      expect(parseIds(List.filled(101, _u)), isNull);
      expect(parseIds(['not-a-uuid']), isNull);
    });
  });
  group('applyPriceMode', () {
    test('set replaces, clamped and rounded', () {
      expect(applyPriceMode(100, 'set', 250.005), 250.01);
      expect(applyPriceMode(100, 'set', -5), 0);
    });
    test('pct applies delta', () {
      expect(applyPriceMode(100, 'pct', 10), 110);
      expect(applyPriceMode(100, 'pct', -100), 0);
    });
  });
}
```

```dart
// test/panel_stats_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:foxy_ads/core/models/listing_model.dart';
import 'package:foxy_ads/features/agency/data/panel_stats.dart';

// Build Listing fixtures via Listing.fromJson with the minimal keys the
// aggregation reads: status, views, is_featured, featured_until, id.
Listing _l({required String id, required String status, int views = 0,
    bool featured = false, String? featuredUntil}) {
  return Listing.fromJson({
    'id': id, 'title': 't', 'price': 1, 'currency': 'EUR', 'images': <String>[],
    'status': status, 'views': views, 'is_featured': featured,
    'featured_until': featuredUntil, 'user_id': 'u', 'category_id': 'c',
    'created_at': '2026-01-01T00:00:00Z',
  });
}

void main() {
  test('computePanelStats aggregates correctly with featured expiry', () {
    final now = DateTime.parse('2026-06-01T00:00:00Z');
    final rows = [
      _l(id: 'a', status: 'active', views: 5, featured: true, featuredUntil: '2026-12-01T00:00:00Z'),
      _l(id: 'b', status: 'active', views: 3, featured: true, featuredUntil: '2026-01-01T00:00:00Z'), // expired
      _l(id: 'c', status: 'sold', views: 2, featured: true), // no expiry -> counts
    ];
    final favs = {'a': 4, 'c': 1};
    final s = computePanelStats(rows, favs, now);
    expect(s.total, 3);
    expect(s.active, 2);
    expect(s.sold, 1);
    expect(s.views, 10);
    expect(s.featured, 2); // a (future) + c (no expiry); b expired
    expect(s.favorites, 5);
  });
}
```

- [ ] **Step 2: Run the tests — expect FAIL** (`flutter test test/agency_validation_test.dart test/panel_pure_test.dart test/panel_stats_test.dart`). Expected: compile errors / unresolved symbols.

- [ ] **Step 3: Implement `agency_model.dart`.**

```dart
// lib/features/agency/data/agency_model.dart
class AgencyProfile {
  final String userId;
  final String name;
  final String createdAt;
  final String? logoUrl, description, website, phone, location;
  final bool isVerified;
  const AgencyProfile({
    required this.userId, required this.name, required this.createdAt,
    this.logoUrl, this.description, this.website, this.phone, this.location,
    required this.isVerified,
  });
  factory AgencyProfile.fromRow(Map<String, dynamic> r) => AgencyProfile(
        userId: r['user_id'] as String,
        name: (r['name'] ?? '') as String,
        logoUrl: r['logo_url'] as String?,
        description: r['description'] as String?,
        website: r['website'] as String?,
        phone: r['phone'] as String?,
        location: r['location'] as String?,
        isVerified: (r['is_verified'] as bool?) ?? false,
        createdAt: (r['created_at'] ?? '') as String,
      );
}

class AgencyInput {
  final String name;
  final String? logoUrl, description, website, phone, location;
  const AgencyInput({
    required this.name, this.logoUrl, this.description, this.website,
    this.phone, this.location,
  });
  Map<String, dynamic> toColumns() => {
        'name': name.trim(),
        'logo_url': logoUrl,
        'description': description?.trim().isEmpty ?? true ? null : description!.trim(),
        'website': website?.trim().isEmpty ?? true ? null : website!.trim(),
        'phone': phone?.trim().isEmpty ?? true ? null : phone!.trim(),
        'location': location?.trim().isEmpty ?? true ? null : location!.trim(),
      };
}

enum AgencyValidationError { name, website, length }

AgencyValidationError? validateAgencyInput(AgencyInput input) {
  final name = input.name.trim();
  if (name.length < 2 || name.length > 120) return AgencyValidationError.name;
  final website = input.website?.trim();
  if (website != null && website.isNotEmpty) {
    if (!RegExp(r'^https?://', caseSensitive: false).hasMatch(website)) {
      return AgencyValidationError.website;
    }
    if (website.length > 300) return AgencyValidationError.length;
  }
  if ((input.description?.length ?? 0) > 2000) return AgencyValidationError.length;
  if ((input.location?.length ?? 0) > 200) return AgencyValidationError.length;
  if ((input.phone?.length ?? 0) > 40) return AgencyValidationError.length;
  return null;
}
```

- [ ] **Step 4: Implement `lead_model.dart`.**

```dart
// lib/features/agency/data/lead_model.dart
const List<String> LEAD_STATUSES = ['new', 'contacted', 'closed'];

class Lead {
  final String id, listingTitle, ownerUserId, buyerName, buyerEmail, message,
      status, createdAt, updatedAt;
  final String? listingId, developmentId, buyerUserId, buyerPhone, notes;
  const Lead({
    required this.id, required this.listingTitle, required this.ownerUserId,
    required this.buyerName, required this.buyerEmail, required this.message,
    required this.status, required this.createdAt, required this.updatedAt,
    this.listingId, this.developmentId, this.buyerUserId, this.buyerPhone,
    this.notes,
  });
  factory Lead.fromRow(Map<String, dynamic> r) => Lead(
        id: r['id'] as String,
        listingId: r['listing_id'] as String?,
        developmentId: r['development_id'] as String?,
        listingTitle: (r['listing_title'] ?? '') as String,
        ownerUserId: (r['owner_user_id'] ?? '') as String,
        buyerUserId: r['buyer_user_id'] as String?,
        buyerName: (r['buyer_name'] ?? '') as String,
        buyerEmail: (r['buyer_email'] ?? '') as String,
        buyerPhone: r['buyer_phone'] as String?,
        message: (r['message'] ?? '') as String,
        status: (r['status'] ?? 'new') as String,
        notes: r['notes'] as String?,
        createdAt: (r['created_at'] ?? '') as String,
        updatedAt: (r['updated_at'] ?? '') as String,
      );
}
```

- [ ] **Step 5: Implement `panel_stats.dart`.**

```dart
// lib/features/agency/data/panel_stats.dart
import '../../../core/models/listing_model.dart';

class DayPoint {
  final String day;
  final int views;
  const DayPoint(this.day, this.views);
}

class PanelStats {
  final int total, active, sold, views, featured, favorites;
  const PanelStats({
    required this.total, required this.active, required this.sold,
    required this.views, required this.featured, required this.favorites,
  });
}

bool _isCurrentlyFeatured(Listing l, DateTime now) {
  if (l.isFeatured != true) return false;
  final until = l.featuredUntil;
  if (until == null || until.isEmpty) return true;
  final t = DateTime.tryParse(until);
  return t != null && t.isAfter(now);
}

PanelStats computePanelStats(
    List<Listing> rows, Map<String, int> favByListing, DateTime now) {
  var active = 0, sold = 0, views = 0, featured = 0, favorites = 0;
  for (final r in rows) {
    if (r.status == 'active') active++;
    if (r.status == 'sold') sold++;
    views += r.views ?? 0;
    favorites += favByListing[r.id] ?? 0;
    if (_isCurrentlyFeatured(r, now)) featured++;
  }
  return PanelStats(
    total: rows.length, active: active, sold: sold, views: views,
    featured: featured, favorites: favorites,
  );
}
```

> **Implementer note:** Read `lib/core/models/listing_model.dart` and confirm the
> exact field names for status/views/is_featured/featured_until/id. If the model
> exposes e.g. `isFeatured`/`featuredUntil`/`views` differently, adapt the
> accessors here and in `panel_stats_test.dart`'s fixture keys accordingly — the
> test fixture uses `Listing.fromJson` with snake_case DB keys, so it exercises
> whatever `fromJson` maps.

- [ ] **Step 6: Extend `development_model.dart`** with `DEVELOPMENT_STATUSES`, `DevelopmentInput`, `validateDevelopmentInput`.

```dart
// append to lib/features/developments/data/development_model.dart
const List<String> DEVELOPMENT_STATUSES = ['planning', 'building', 'ready'];

class DevelopmentInput {
  final String name, countryCode;
  final String? description, promoterName, city, address, deliveryLabel, status;
  final double? latitude, longitude;
  final List<String> amenities, images;
  const DevelopmentInput({
    required this.name, required this.countryCode, this.description,
    this.promoterName, this.city, this.address, this.deliveryLabel,
    this.status, this.latitude, this.longitude,
    this.amenities = const [], this.images = const [],
  });
  Map<String, dynamic> toColumns() => {
        'name': name.trim(),
        'description': description?.trim().isEmpty ?? true ? null : description!.trim(),
        'promoter_name': promoterName?.trim().isEmpty ?? true ? null : promoterName!.trim(),
        'country_code': countryCode.trim(),
        'city': city?.trim().isEmpty ?? true ? null : city!.trim(),
        'address': address?.trim().isEmpty ?? true ? null : address!.trim(),
        'latitude': latitude,
        'longitude': longitude,
        'amenities': amenities,
        'images': images,
        'delivery_label': deliveryLabel?.trim().isEmpty ?? true ? null : deliveryLabel!.trim(),
        'status': status ?? 'planning',
      };
}

enum DevelopmentValidationError { name, country, status, description, length }

DevelopmentValidationError? validateDevelopmentInput(DevelopmentInput input) {
  final name = input.name.trim();
  if (name.length < 2 || name.length > 140) return DevelopmentValidationError.name;
  final cc = input.countryCode.trim();
  if (cc.length < 2 || cc.length > 5) return DevelopmentValidationError.country;
  if (input.status != null && !DEVELOPMENT_STATUSES.contains(input.status)) {
    return DevelopmentValidationError.status;
  }
  if ((input.description?.length ?? 0) > 5000) return DevelopmentValidationError.description;
  if ((input.promoterName?.length ?? 0) > 140) return DevelopmentValidationError.length;
  if ((input.city?.length ?? 0) > 120) return DevelopmentValidationError.length;
  if ((input.address?.length ?? 0) > 240) return DevelopmentValidationError.length;
  if ((input.deliveryLabel?.length ?? 0) > 60) return DevelopmentValidationError.length;
  return null;
}
```

- [ ] **Step 7: Add `parseIds` + `applyPriceMode` to `listing_service.dart`** (top-level functions, exported).

```dart
// add near the top of lib/core/services/listing_service.dart (top-level)
final RegExp _uuidRe = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

List<String>? parseIds(List<String> ids) {
  if (ids.isEmpty || ids.length > 100) return null;
  if (!ids.every(_uuidRe.hasMatch)) return null;
  return ids.map((e) => e.toLowerCase()).toSet().toList();
}

double applyPriceMode(double current, String mode, double value) {
  final raw = mode == 'set' ? value : current * (1 + value / 100);
  final clamped = raw < 0 ? 0.0 : raw;
  return (clamped * 100).round() / 100;
}
```

- [ ] **Step 8: Run the three tests — expect PASS.** `flutter test test/agency_validation_test.dart test/panel_pure_test.dart test/panel_stats_test.dart`.

- [ ] **Step 9: `flutter analyze` (0 errors) then commit.**

```bash
git add -A && git commit -m "feat(agency): models + validation + pure panel helpers"
```

---

## Task 2: AgencyService + providers

**Files:**
- Create: `lib/features/agency/data/agency_service.dart`
- Test: (covered by T3's widget test — no standalone test here; the fetch methods are thin Supabase reads mirroring `DevelopmentsService`)

**Interfaces produced:** `agencyServiceProvider`, `myAgencyProfileProvider`,
`agencyProfileProvider` (family), `agencyListingsProvider` (family), and the
`AgencyService` methods below. Consumed by T3/T4/T5.

- [ ] **Step 1: Implement `AgencyService` + providers.** Mirror the shape of
  `lib/features/developments/data/developments_service.dart` (client injection,
  provider style). Read that file + `agency.ts` (web) first.

```dart
// lib/features/agency/data/agency_service.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../core/models/listing_model.dart';
import 'agency_model.dart';

const _agencySelect =
    'user_id, name, logo_url, description, website, phone, location, is_verified, created_at';
const _agencyListingsPageSize = 24;

class AgencyListingsArgs {
  final String userId;
  final int page;
  const AgencyListingsArgs(this.userId, this.page);
  @override
  bool operator ==(Object o) =>
      o is AgencyListingsArgs && o.userId == userId && o.page == page;
  @override
  int get hashCode => Object.hash(userId, page);
}

class AgencyService {
  final SupabaseClient _supabase;
  AgencyService(this._supabase);

  Future<AgencyProfile?> fetchAgencyProfile(String userId) async {
    final row = await _supabase
        .from('agency_profiles')
        .select(_agencySelect)
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) return null;
    return AgencyProfile.fromRow(row);
  }

  Future<({List<Listing> items, bool hasMore})> fetchAgencyListings(
      String userId, int page) async {
    final from = page * _agencyListingsPageSize;
    final to = from + _agencyListingsPageSize - 1;
    final rows = await _supabase
        .from('listings')
        .select() // full row -> Listing.fromJson
        .eq('user_id', userId)
        .eq('status', 'active')
        .order('created_at', ascending: false)
        .range(from, to);
    final items = (rows as List)
        .map((e) => Listing.fromJson(e as Map<String, dynamic>))
        .toList();
    return (items: items, hasMore: items.length == _agencyListingsPageSize);
  }

  /// Upsert the caller's own agency profile. NEVER writes is_verified.
  Future<AgencyProfile?> upsertAgencyProfile(
      String userId, AgencyInput input) async {
    final row = await _supabase
        .from('agency_profiles')
        .upsert({...input.toColumns(), 'user_id': userId})
        .select(_agencySelect)
        .maybeSingle();
    return row == null ? null : AgencyProfile.fromRow(row);
  }

  /// Upload a logo to storage; returns the public URL. Mirrors
  /// ListingService.uploadImages' bucket + public-URL pattern (read that first).
  Future<String> uploadAgencyLogo(String userId, XFile file) async {
    final bytes = await file.readAsBytes();
    final ext = file.name.contains('.') ? file.name.split('.').last : 'jpg';
    final path = 'agency-logos/$userId/${DateTime.now().millisecondsSinceEpoch}.$ext';
    // Use the SAME bucket name ListingService.uploadImages uses.
    const bucket = 'listings'; // implementer: confirm the bucket from uploadImages
    await _supabase.storage.from(bucket).uploadBinary(path, bytes,
        fileOptions: const FileOptions(upsert: true));
    return _supabase.storage.from(bucket).getPublicUrl(path);
  }
}

final agencyServiceProvider =
    Provider<AgencyService>((ref) => AgencyService(ref.watch(supabaseClientProvider)));

/// The signed-in user's own agency profile — the panel gate. null when
/// signed-out or no profile. Watches auth so it re-resolves on login/logout.
final myAgencyProfileProvider = FutureProvider<AgencyProfile?>((ref) async {
  final user = ref.watch(authStateProvider).value; // import auth_service.dart
  if (user == null) return null;
  return ref.watch(agencyServiceProvider).fetchAgencyProfile(user.id);
});

final agencyProfileProvider =
    FutureProvider.family<AgencyProfile?, String>((ref, id) =>
        ref.watch(agencyServiceProvider).fetchAgencyProfile(id));

final agencyListingsProvider = FutureProvider.family<
    ({List<Listing> items, bool hasMore}), AgencyListingsArgs>((ref, args) =>
    ref.watch(agencyServiceProvider).fetchAgencyListings(args.userId, args.page));
```

> **Implementer notes:** (1) Import `authStateProvider` from
> `lib/core/services/auth_service.dart`. (2) Open `ListingService.uploadImages`
> and copy its EXACT bucket name + upload/publicUrl calls into
> `uploadAgencyLogo` (the `'listings'` literal above is a placeholder). (3) If
> `Listing.fromJson` requires keys a bare `listings` row lacks (e.g.
> `user_name`), the Sprint-3 developments units query already proved a plain
> `.select()` row parses — mirror that.

- [ ] **Step 2: `flutter analyze` (0 errors), `flutter test` (full suite green), commit.**

```bash
git add -A && git commit -m "feat(agency): AgencyService + providers"
```

---

## Task 3: Public agency profile screen `/agencia/:id`

**Files:**
- Create: `lib/features/agency/presentation/widgets/agency_verified_badge.dart`
- Create: `lib/features/agency/presentation/screens/agency_profile_screen.dart`
- Modify: `lib/core/router/app_router.dart` (route + `AppRoutes.agencyProfile(id)`)
- Test: `test/agency_profile_screen_test.dart`

**Interfaces produced:** `AgencyProfileScreen({required String agencyId})`;
`AgencyVerifiedBadge({required bool verified})`;
`AppRoutes.agencyProfile(String id) => '/agencia/$id'`.

- [ ] **Step 1: Write the widget test** (`test/agency_profile_screen_test.dart`):
  a `FakeAgencyService extends AgencyService` overriding `fetchAgencyProfile`
  (returns a fixed profile or null) and `fetchAgencyListings` (returns `[]` or
  N). Follow the exact fake-SupabaseClient(`autoRefreshToken:false`) +
  `ProviderScope` override pattern used in `test/promociones_screen_test.dart`
  (Sprint 3). Assert: null profile → "Agencia no encontrada"; profile + `[]` →
  empty-state text; profile + 2 → 2 `ListingCard`s.

- [ ] **Step 2: Run — expect FAIL.**

- [ ] **Step 3: Implement `AgencyVerifiedBadge`** — a small chip: verified →
  primary-tinted "Agencia verificada" with a check icon; not verified → a muted
  "Agencia" chip. Use `AppColors`.

- [ ] **Step 4: Implement `AgencyProfileScreen`** (`ConsumerStatefulWidget` to
  hold the `page` int). Watch `agencyProfileProvider(agencyId)` and
  `agencyListingsProvider(AgencyListingsArgs(agencyId, page))`. Header card:
  logo (`CachedNetworkImage`) or initial-letter fallback, name, `AgencyVerifiedBadge`,
  whitespace-pre-line description, and website (url_launcher `externalApplication`)
  / phone / location rows. Then a "Anuncios" heading + a 2-col grid of
  `ListingCard`, and prev/next buttons gated on `page > 0` / `hasMore` (setState
  the page, which re-reads the family provider). `null` profile → "Agencia no
  encontrada" scaffold. Loading → spinner; error → error state.

- [ ] **Step 5: Add the route** `/agencia/:id` (reads `state.pathParameters['id']!`)
  + `AppRoutes.agencyProfile`.

- [ ] **Step 6: Run the test (PASS), `flutter analyze` (0 errors), commit.**

```bash
git add -A && git commit -m "feat(agency): public /agencia/:id profile screen"
```

---

## Task 4: Agency profile edit `/agencia/editar` + logo upload

**Files:**
- Create: `lib/features/agency/presentation/screens/agency_profile_edit_screen.dart`
- Modify: `lib/core/router/app_router.dart` (route + `AppRoutes.agencyEdit`)

**Interfaces produced:** `AgencyProfileEditScreen`; `AppRoutes.agencyEdit = '/agencia/editar'`.

- [ ] **Step 1: Implement `AgencyProfileEditScreen`** (`ConsumerStatefulWidget`).
  Auth-gated: if `authStateProvider.value == null`, show a "Inicia sesión"
  scaffold. Prefill controllers from `myAgencyProfileProvider` (when loaded).
  Fields: name (required), description (multiline), website, phone, location,
  and a logo picker (image_picker `pickImage`; on pick, call
  `agencyService.uploadAgencyLogo(userId, file)`, store the URL, show a preview
  via `CachedNetworkImage`). On save: build `AgencyInput`, run
  `validateAgencyInput` (map each error to a Spanish message under the right
  field / SnackBar), call `upsertAgencyProfile`, then
  `ref.invalidate(myAgencyProfileProvider)`, success SnackBar, `context.pop()`.
  A pending flag disables Save. Never renders `is_verified`.

- [ ] **Step 2: Add route** `/agencia/editar` + `AppRoutes.agencyEdit`.

- [ ] **Step 3: `flutter analyze` (0 errors), `flutter test` (green), commit.**

```bash
git add -A && git commit -m "feat(agency): editable agency profile + logo upload"
```

---

## Task 5: Pro Dashboard shell + verified gate + Stats

**Files:**
- Create: `lib/features/agency/presentation/widgets/panel_stats_cards.dart`
- Create: `lib/features/agency/presentation/screens/panel_screen.dart`
- Modify: `lib/core/router/app_router.dart` (route + `AppRoutes.panel`)
- Test: `test/panel_gate_test.dart`

**Interfaces produced:** `PanelScreen`; `PanelStatsCards({required PanelStats stats})`;
`AppRoutes.panel = '/panel'`. The dashboard body is assembled here and extended
by T6/T7/T10/T12 (each adds its section widget into the panel's scroll view).

- [ ] **Step 1: Write `test/panel_gate_test.dart`** — override
  `myAgencyProfileProvider`: (a) a `null`/unverified profile → the panel shows
  the "Panel Pro" explainer + CTA, and NOT the stats section; (b) a verified
  profile (with a fake listings source) → the dashboard renders (assert a stats
  heading/tile is present). Use a provider override that supplies an
  `AsyncData<AgencyProfile?>` directly (no Supabase needed for the gate branch).

- [ ] **Step 2: Run — expect FAIL.**

- [ ] **Step 3: Implement `PanelStatsCards`** — a responsive grid of 6 tiles
  (total/activos/vendidos/vistas/destacados/favoritos) from a `PanelStats`.
  Style as compact cards using `AppColors` (mirror the Sprint-3 card styling;
  there is no shared `StatCard` widget in Flutter yet — build a small local
  tile).

- [ ] **Step 4: Implement `PanelScreen`** (`ConsumerWidget`). Watch
  `myAgencyProfileProvider`:
  - loading → spinner scaffold;
  - data `null` or `isVerified == false` → an explainer scaffold ("Panel Pro —
    disponible para agencias verificadas") with a CTA button to
    `AppRoutes.agencyEdit` (create/complete your agency profile);
  - verified → a `ListView`/`CustomScrollView` dashboard. For THIS task the body
    contains only the Stats section: read the agency's own listings (add a
    `myPanelListingsProvider` here — a `FutureProvider<List<Listing>>` using
    `ListingService.getUserListings(uid)` filtered to non-deleted — and a
    favorites-count map via a second query; compute `computePanelStats(rows,
    favs, DateTime.now())`). Render `PanelStatsCards`. Leave a clearly-commented
    slot (`// Sections added by later tasks: views chart (T6), leads (T7),
    developments (T10), bulk (T12)`) where subsequent tasks insert their widgets.

> **Provider for panel listings:** add to `agency_service.dart` (or the panel
> screen file) `myPanelListingsProvider` returning the signed-in user's
> non-deleted listings + a `panelFavoritesProvider` (map listingId→count) via
> `favorites` `.inFilter('listing_id', ids)`. Non-fatal on error (empty map).

- [ ] **Step 5: Add route** `/panel` + `AppRoutes.panel`.

- [ ] **Step 6: Run test (PASS), `flutter analyze` (0 errors), commit.**

```bash
git add -A && git commit -m "feat(panel): dashboard shell + verified gate + stats"
```

---

## Task 6: Views chart (CustomPainter) + getAgencyViewsSeries

**Files:**
- Modify: `lib/core/services/listing_service.dart` (add `getAgencyViewsSeries`)
- Create: `lib/features/agency/presentation/widgets/panel_views_chart.dart`
- Modify: `lib/features/agency/presentation/screens/panel_screen.dart` (insert the chart section)

**Interfaces produced:** `ListingService.getAgencyViewsSeries({int days})`,
`viewsSeriesProvider` (FutureProvider<List<DayPoint>>), `PanelViewsChart`.

- [ ] **Step 1: Add `getAgencyViewsSeries` to `ListingService`.**

```dart
// import panel_stats.dart's DayPoint
Future<List<DayPoint>> getAgencyViewsSeries({int days = 30}) async {
  final uid = _supabase.auth.currentUser?.id;
  if (uid == null) return const [];
  try {
    final data = await _supabase.rpc('agency_daily_views',
        params: {'p_user_id': uid, 'p_days': days});
    return (data as List)
        .map((e) => DayPoint(
              (e['day'] ?? '').toString(),
              int.tryParse((e['views'] ?? 0).toString()) ?? 0,
            ))
        .toList();
  } catch (_) {
    return const [];
  }
}
```

- [ ] **Step 2: Implement `PanelViewsChart`** — a `CustomPaint` rendering a
  line/bar over ≤30 `DayPoint`s with a baseline, max-scaled heights, and a
  muted "Sin datos" state when empty. Fixed height (~160). Use `AppColors.primary`
  for the series. No dependency.

- [ ] **Step 3: Insert a `viewsSeriesProvider`** (`FutureProvider<List<DayPoint>>`
  → `getAgencyViewsSeries()`) and render `PanelViewsChart` in the panel's
  verified body, above the leads slot.

- [ ] **Step 4: `flutter analyze` (0 errors), `flutter test` (green), commit.**

```bash
git add -A && git commit -m "feat(panel): views-over-time chart"
```

---

## Task 7: CRM leads inbox

**Files:**
- Modify: `lib/core/services/leads_service.dart` (add list/update methods + providers + `LeadActionOutcome`)
- Create: `lib/features/agency/presentation/widgets/leads_panel.dart`
- Modify: `lib/features/agency/presentation/screens/panel_screen.dart` (insert leads section)
- Test: `test/leads_panel_test.dart`

**Interfaces produced:** `LeadsService.listAgencyLeads({LeadStatus? status})`,
`updateLeadStatus`, `updateLeadNotes`, `LeadActionOutcome`, `agencyLeadsProvider`
(family), `newLeadsCountProvider`, `LeadsPanel`.

- [ ] **Step 1: Add the lead methods to `LeadsService`.** Read the current
  `leads_service.dart` first (it already has `submitLead`/`submitDevelopmentLead`
  + `LeadSubmitOutcome`). Add:

```dart
enum LeadActionError { unauthenticated, forbidden, invalidInput, databaseError }
class LeadActionOutcome {
  final bool ok; final LeadActionError? error;
  const LeadActionOutcome.ok() : ok = true, error = null;
  const LeadActionOutcome.err(this.error) : ok = false;
}

Future<List<Lead>> listAgencyLeads({String? status}) async {
  final uid = _supabase.auth.currentUser?.id;
  if (uid == null) return const [];
  var q = _supabase.from('leads').select().eq('owner_user_id', uid);
  if (status != null && status != 'all') q = q.eq('status', status);
  final rows = await q.order('created_at', ascending: false);
  return (rows as List).map((e) => Lead.fromRow(e as Map<String, dynamic>)).toList();
}

Future<LeadActionOutcome> updateLeadStatus(String id, String status) async {
  final uid = _supabase.auth.currentUser?.id;
  if (uid == null) return const LeadActionOutcome.err(LeadActionError.unauthenticated);
  if (!LEAD_STATUSES.contains(status) || !_uuidRe.hasMatch(id)) {
    return const LeadActionOutcome.err(LeadActionError.invalidInput);
  }
  try {
    await _supabase.from('leads').update({'status': status})
        .eq('id', id).eq('owner_user_id', uid);
    return const LeadActionOutcome.ok();
  } catch (_) {
    return const LeadActionOutcome.err(LeadActionError.databaseError);
  }
}

Future<LeadActionOutcome> updateLeadNotes(String id, String notes) async {
  final uid = _supabase.auth.currentUser?.id;
  if (uid == null) return const LeadActionOutcome.err(LeadActionError.unauthenticated);
  if (!_uuidRe.hasMatch(id)) return const LeadActionOutcome.err(LeadActionError.invalidInput);
  final trimmed = notes.trim();
  if (trimmed.length > 4000) return const LeadActionOutcome.err(LeadActionError.invalidInput);
  try {
    await _supabase.from('leads')
        .update({'notes': trimmed.isEmpty ? null : trimmed})
        .eq('id', id).eq('owner_user_id', uid);
    return const LeadActionOutcome.ok();
  } catch (_) {
    return const LeadActionOutcome.err(LeadActionError.databaseError);
  }
}
```

> Import `Lead`/`LEAD_STATUSES` from `agency/data/lead_model.dart` and reuse the
> `_uuidRe` from `listing_service.dart` — either re-declare a private copy in
> leads_service.dart or expose the one from listing_service. Prefer a small
> private `_uuidRe` local to leads_service to avoid a cross-file coupling.

Providers (in leads_service.dart):
```dart
final agencyLeadsProvider = FutureProvider.family<List<Lead>, String?>(
    (ref, status) => ref.watch(leadsServiceProvider).listAgencyLeads(status: status));
final newLeadsCountProvider = FutureProvider<int>((ref) async =>
    (await ref.watch(leadsServiceProvider).listAgencyLeads(status: 'new')).length);
```

- [ ] **Step 2: Write `test/leads_panel_test.dart`** — a `FakeLeadsService`
  returning a fixed lead list (and `[]`); pump `LeadsPanel` in a `ProviderScope`
  overriding `leadsServiceProvider`; assert: N leads → N cards; empty → empty
  state; tapping a status change invokes `updateLeadStatus` (spy).

- [ ] **Step 3: Run — expect FAIL.**

- [ ] **Step 4: Implement `LeadsPanel`** (`ConsumerStatefulWidget`) — mirror the
  web `LeadsPanel`: a heading + new-count badge (`newLeadsCountProvider`), a
  status filter dropdown (all + LEAD_STATUSES), and a list of lead cards. Each
  card: buyer name, a link to `/promocion/:id` when `developmentId != null` else
  the `listingTitle`, a status dropdown (`updateLeadStatus`; optimistic in-list
  update + `ref.invalidate(newLeadsCountProvider)`), the message (pre-wrap),
  `mailto:`/`tel:` links + date, and a notes textarea + Save (`updateLeadNotes`).
  Spanish error SnackBar on `!ok`.

- [ ] **Step 5: Insert `LeadsPanel`** into the panel's verified body (below the
  chart).

- [ ] **Step 6: Run test (PASS), `flutter analyze` (0 errors), commit.**

```bash
git add -A && git commit -m "feat(panel): CRM leads inbox"
```

---

## Task 8: Developments service CRUD + assign

**Files:**
- Modify: `lib/features/developments/data/developments_service.dart`

**Interfaces produced:** `DevActionOutcome<T>`, `createDevelopment`,
`updateDevelopment`, `deleteDevelopment`, `listMyDevelopments`,
`assignListingsToDevelopment`, `uploadDevelopmentImages`, `myDevelopmentsProvider`.

- [ ] **Step 1: Add the CRUD + assign methods** to `DevelopmentsService`
  (mirror `developments.ts` web ownership guards + `parseIds`). Read the existing
  service first.

```dart
enum DevActionError { unauthenticated, forbidden, invalidInput, databaseError }
class DevActionOutcome<T> {
  final bool ok; final DevActionError? error; final T? data;
  const DevActionOutcome.ok([this.data]) : ok = true, error = null;
  const DevActionOutcome.err(this.error) : ok = false, data = null;
}

Future<DevActionOutcome<String>> createDevelopment(DevelopmentInput input) async {
  final uid = _supabase.auth.currentUser?.id;
  if (uid == null) return const DevActionOutcome.err(DevActionError.unauthenticated);
  if (validateDevelopmentInput(input) != null) {
    return const DevActionOutcome.err(DevActionError.invalidInput);
  }
  try {
    final row = await _supabase.from('developments')
        .insert({...input.toColumns(), 'agency_user_id': uid})
        .select('id').single();
    return DevActionOutcome.ok(row['id'] as String);
  } catch (_) {
    return const DevActionOutcome.err(DevActionError.databaseError);
  }
}

Future<DevActionOutcome<void>> updateDevelopment(String id, DevelopmentInput input) async {
  final uid = _supabase.auth.currentUser?.id;
  if (uid == null) return const DevActionOutcome.err(DevActionError.unauthenticated);
  if (!_uuidRe.hasMatch(id) || validateDevelopmentInput(input) != null) {
    return const DevActionOutcome.err(DevActionError.invalidInput);
  }
  try {
    await _supabase.from('developments').update(input.toColumns())
        .eq('id', id).eq('agency_user_id', uid);
    return const DevActionOutcome.ok();
  } catch (_) {
    return const DevActionOutcome.err(DevActionError.databaseError);
  }
}

Future<DevActionOutcome<void>> deleteDevelopment(String id) async {
  final uid = _supabase.auth.currentUser?.id;
  if (uid == null) return const DevActionOutcome.err(DevActionError.unauthenticated);
  if (!_uuidRe.hasMatch(id)) return const DevActionOutcome.err(DevActionError.invalidInput);
  try {
    await _supabase.from('developments').delete().eq('id', id).eq('agency_user_id', uid);
    return const DevActionOutcome.ok();
  } catch (_) {
    return const DevActionOutcome.err(DevActionError.databaseError);
  }
}

Future<List<Development>> listMyDevelopments() async {
  final uid = _supabase.auth.currentUser?.id;
  if (uid == null) return const [];
  final rows = await _supabase.from('developments').select()
      .eq('agency_user_id', uid).order('created_at', ascending: false);
  return (rows as List).map((e) => Development.fromRow(e as Map<String, dynamic>)).toList();
}

Future<DevActionOutcome<void>> assignListingsToDevelopment(
    String? developmentId, List<String> listingIds) async {
  final uid = _supabase.auth.currentUser?.id;
  if (uid == null) return const DevActionOutcome.err(DevActionError.unauthenticated);
  final ids = parseIds(listingIds); // from listing_service.dart
  if (ids == null) return const DevActionOutcome.err(DevActionError.invalidInput);
  // assert all listings owned
  final owned = await _supabase.from('listings').select('id')
      .eq('user_id', uid).inFilter('id', ids);
  if ((owned as List).length != ids.length) {
    return const DevActionOutcome.err(DevActionError.forbidden);
  }
  if (developmentId != null) {
    if (!_uuidRe.hasMatch(developmentId)) {
      return const DevActionOutcome.err(DevActionError.invalidInput);
    }
    final dev = await _supabase.from('developments').select('id')
        .eq('id', developmentId).eq('agency_user_id', uid);
    if ((dev as List).isEmpty) return const DevActionOutcome.err(DevActionError.forbidden);
  }
  try {
    await _supabase.from('listings').update({'development_id': developmentId})
        .inFilter('id', ids).eq('user_id', uid);
    return const DevActionOutcome.ok();
  } catch (_) {
    return const DevActionOutcome.err(DevActionError.databaseError);
  }
}

Future<List<String>> uploadDevelopmentImages(List<XFile> files) async {
  // Reuse ListingService.uploadImages' bucket + path pattern; return public URLs.
}

final myDevelopmentsProvider = FutureProvider<List<Development>>(
    (ref) => ref.watch(developmentsServiceProvider).listMyDevelopments());
```

> Import `parseIds` + `_uuidRe` intent from `listing_service.dart` (or a small
> private `_uuidRe` copy). Import `DevelopmentInput`/`validateDevelopmentInput`
> from `development_model.dart`. `uploadDevelopmentImages` mirrors the Sprint-3/1
> upload path — read `ListingService.uploadImages`.

- [ ] **Step 2: `flutter analyze` (0 errors), `flutter test` (green), commit.**

```bash
git add -A && git commit -m "feat(developments): agency CRUD + assign service"
```

---

## Task 9: Development create/edit form screen

**Files:**
- Create: `lib/features/developments/presentation/screens/development_form_screen.dart`
- Modify: `lib/core/router/app_router.dart` (routes + `AppRoutes.developmentCreate`, `AppRoutes.developmentEdit(id)`)

**Interfaces produced:** `DevelopmentFormScreen({String? developmentId})`;
`AppRoutes.developmentCreate = '/promocion-editar'`;
`AppRoutes.developmentEdit(String id) => '/promocion-editar/$id'`.

- [ ] **Step 1: Implement `DevelopmentFormScreen`** (`ConsumerStatefulWidget`).
  Auth + verified gate (watch `myAgencyProfileProvider`; if not verified → a
  "solo agencias verificadas" scaffold). On `developmentId != null`, prefill from
  `developmentDetailProvider(developmentId)` (Sprint 3). Fields: name (required),
  description, promoterName, countryCode (default `selectedCountryProvider.code`),
  city, address, latitude, longitude, amenities (add/remove chips), images
  (image_picker multi → `uploadDevelopmentImages` → reorderable/removable
  previews), deliveryLabel, status (dropdown of DEVELOPMENT_STATUSES with Spanish
  labels: En planos / En construcción / Lista para entrar). On save: build
  `DevelopmentInput`, `validateDevelopmentInput` (Spanish error mapping), call
  `createDevelopment`/`updateDevelopment`, `ref.invalidate(myDevelopmentsProvider)`
  (and `developmentDetailProvider(id)` on edit), SnackBar, pop. Pending flag
  disables Save.

- [ ] **Step 2: Add routes** `/promocion-editar` and `/promocion-editar/:id`
  + `AppRoutes` entries.

- [ ] **Step 3: `flutter analyze` (0 errors), `flutter test` (green), commit.**

```bash
git add -A && git commit -m "feat(developments): create/edit form screen"
```

---

## Task 10: Developments panel section (list + delete + assign) + wire into panel

**Files:**
- Create: `lib/features/agency/presentation/widgets/developments_panel.dart`
- Modify: `lib/features/agency/presentation/screens/panel_screen.dart`

**Interfaces produced:** `DevelopmentsPanel`.

- [ ] **Step 1: Implement `DevelopmentsPanel`** (`ConsumerWidget`) — watches
  `myDevelopmentsProvider`; a "Crear promoción" button → `AppRoutes.developmentCreate`;
  a list of dev rows (name, city, status badge, unit count if cheap) each with:
  Editar → `AppRoutes.developmentEdit(id)`; Borrar → confirm dialog →
  `deleteDevelopment` → invalidate; "Asignar anuncios" → a bottom sheet listing
  the agency's own listings (from `myPanelListingsProvider`) with checkboxes,
  pre-checked when a listing's `development_id == dev.id`, Save →
  `assignListingsToDevelopment(dev.id, selectedIds)` (and, for unchecked
  previously-assigned ones, a second call with `null` to clear — or compute the
  net set: assign checked to dev.id, clear unchecked-that-were-his). Empty state
  when no developments. Spanish error SnackBars.

> **Assign semantics:** to keep it simple and correct, on Save compute two id
> sets from the sheet: `toAssign` (checked) → `assignListingsToDevelopment(dev.id,
> toAssign)`; `toClear` (unchecked AND currently `development_id == dev.id`) →
> `assignListingsToDevelopment(null, toClear)`. Skip a call when its set is empty.

- [ ] **Step 2: Insert `DevelopmentsPanel`** into the panel's verified body
  (below leads).

- [ ] **Step 3: `flutter analyze` (0 errors), `flutter test` (green), commit.**

```bash
git add -A && git commit -m "feat(panel): developments management section"
```

---

## Task 11: Bulk listing ops service + CSV

**Files:**
- Modify: `lib/core/services/listing_service.dart` (add bulk methods + `listingsToCsv` + `PanelActionOutcome`)

**Interfaces produced:** `PanelActionOutcome`, `bulkSetStatus`, `bulkDelete`,
`bulkRenew`, `bulkSetPrice`, `listingsToCsv`.

- [ ] **Step 1: Add the bulk methods + CSV.**

```dart
enum PanelActionError { unauthenticated, forbidden, invalidInput, databaseError }
class PanelActionOutcome {
  final bool ok; final PanelActionError? error;
  const PanelActionOutcome.ok() : ok = true, error = null;
  const PanelActionOutcome.err(this.error) : ok = false;
}

Future<bool> _assertAllOwned(String uid, List<String> ids) async {
  final rows = await _supabase.from('listings').select('id')
      .eq('user_id', uid).inFilter('id', ids).neq('status', 'deleted');
  return (rows as List).length == ids.length;
}

Future<PanelActionOutcome> bulkSetStatus(List<String> rawIds, String status) async {
  final uid = _supabase.auth.currentUser?.id;
  if (uid == null) return const PanelActionOutcome.err(PanelActionError.unauthenticated);
  if (!['active', 'inactive', 'sold'].contains(status)) {
    return const PanelActionOutcome.err(PanelActionError.invalidInput);
  }
  final ids = parseIds(rawIds);
  if (ids == null) return const PanelActionOutcome.err(PanelActionError.invalidInput);
  if (!await _assertAllOwned(uid, ids)) {
    return const PanelActionOutcome.err(PanelActionError.forbidden);
  }
  try {
    await _supabase.from('listings').update({'status': status})
        .inFilter('id', ids).eq('user_id', uid);
    return const PanelActionOutcome.ok();
  } catch (_) { return const PanelActionOutcome.err(PanelActionError.databaseError); }
}

// bulkDelete -> update status='deleted'; bulkRenew -> update created_at=now,
// .neq('status','deleted'); each: parseIds -> _assertAllOwned -> mutate.
// bulkSetPrice(rawIds, mode, value): validate mode in {set,pct} + finite value +
// (set => value>=0); fetch owned id+price (.neq deleted); count must equal
// ids.length else FORBIDDEN; per row update price = applyPriceMode(price, mode, value).

/// RFC-4180 CSV, CRLF rows, columns matching web toListingsCsv. Read
/// src/lib/panel/csv.ts for the exact header + column order + quoting.
String listingsToCsv(List<Listing> rows) { /* header + one line per row */ }
```

> **Implementer:** open `foxy_ads_web/src/lib/panel/csv.ts` and reproduce its
> HEADER string, column order, quoting (double inner quotes, wrap when the field
> contains `,` `"` or newline), and `\r\n` row join EXACTLY, using the Flutter
> `Listing` fields. Implement `bulkDelete`/`bulkRenew`/`bulkSetPrice` per the
> comments, mirroring `panel.ts`.

- [ ] **Step 2: `flutter analyze` (0 errors), `flutter test` (green), commit.**

```bash
git add -A && git commit -m "feat(panel): bulk listing ops + CSV service"
```

---

## Task 12: Bulk listings panel section + CSV share + wire into panel

**Files:**
- Create: `lib/features/agency/presentation/widgets/bulk_listings_panel.dart`
- Modify: `lib/features/agency/presentation/screens/panel_screen.dart`

**Interfaces produced:** `BulkListingsPanel`.

- [ ] **Step 1: Implement `BulkListingsPanel`** (`ConsumerStatefulWidget`) —
  lists `myPanelListingsProvider` rows with a per-row checkbox + a select-all
  (current list), a bulk toolbar visible only when the selection is non-empty:
  set status (active/inactive/sold), set price (a small dialog: mode set|pct +
  value), renew, delete (confirm). On any successful mutation: clear selection +
  invalidate `myPanelListingsProvider` (+ the stats provider). An "Exportar CSV"
  button → `listingsToCsv(rows)` written to a temp file in the scratch/app-temp
  dir and shared via `SharePlus.instance.share(...)` (mirror the app's existing
  Share usage — grep for `SharePlus`/`Share`). Spanish error SnackBars.

- [ ] **Step 2: Insert `BulkListingsPanel`** into the panel's verified body
  (below developments).

- [ ] **Step 3: `flutter analyze` (0 errors), `flutter test` (green), commit.**

```bash
git add -A && git commit -m "feat(panel): bulk listings section + CSV export"
```

---

## Task 13: Entry points (profile tile + listing-detail agency link)

**Files:**
- Modify: `lib/features/profile/presentation/screens/profile_screen.dart`
- Modify: the listing detail screen (find it: `lib/features/listings/.../listing_detail_screen.dart`)

- [ ] **Step 1: Profile "Panel Pro" tile.** In `profile_screen.dart`, watch
  `myAgencyProfileProvider`; when it resolves to a verified profile, render a
  "Panel Pro" ListTile (with a subtitle like "Gestiona tu agencia") → `context.push(AppRoutes.panel)`.
  Also add an always-available "Mi agencia" tile → `AppRoutes.agencyEdit` (so a
  seller can create/complete an agency profile). Keep placement consistent with
  the existing tiles.

- [ ] **Step 2: Listing-detail "Ver agencia" link.** On the listing detail's
  seller section, look up whether the seller has an agency profile
  (`agencyProfileProvider(sellerUserId)`); when present, show a "Ver agencia"
  link → `context.push(AppRoutes.agencyProfile(sellerUserId))`. If wiring the
  seller id is not cleanly available, add the link only where the seller id is
  already in scope; do not over-reach.

- [ ] **Step 3: `flutter analyze` (0 errors), `flutter test` (green), commit.**

```bash
git add -A && git commit -m "feat(agency): profile + listing-detail entry points"
```

---

## Task 14: Final whole-branch review

Dispatch one final code-reviewer subagent on the most-capable model. Provide the
review package (`scripts/review-package MERGE_BASE HEAD`, MERGE_BASE = the commit
Sprint 4 started from), `git log --oneline`, and the Global Constraints block as
the attention lens. Reviewer checks: spec coverage, no over/under-building,
`flutter analyze` 0 errors, full suite green, `flutter build apk --debug` builds,
the verified-gate + RLS-ownership posture is intact across every write path, no
service-role usage, CSV/validation parity vs web, and no cross-task integration
seams (provider signatures, route dedup, upload bucket consistency). Triage
Critical → dispatch ONE fix subagent with the complete list.

---

## Self-Review (author)

- **Spec coverage:** every spec deliverable maps to a task — models/validation
  (T1), AgencyService (T2), public profile (T3), edit+logo (T4), panel shell +
  gate + stats (T5), views chart (T6), CRM (T7), dev CRUD/assign service (T8),
  dev form (T9), dev panel (T10), bulk service (T11), bulk panel + CSV (T12),
  entry points (T13), final review (T14). ✓
- **Type consistency:** `AgencyProfile`/`AgencyInput`/`Lead`/`DevelopmentInput`
  signatures are declared once (T1) and consumed by name thereafter;
  `parseIds`/`applyPriceMode` (T1) reused by T8/T11; `myAgencyProfileProvider`
  (T2) gates T5/T9/T13; `myPanelListingsProvider` introduced in T5 and reused by
  T10/T12. Outcome enums are per-domain but structurally identical (documented).
- **Placeholder scan:** the two deliberate "confirm from the existing file"
  notes (upload bucket name; CSV column set) point at concrete web/Flutter
  source the implementer must read — not vague TODOs; every pure unit has full
  code + full tests.
