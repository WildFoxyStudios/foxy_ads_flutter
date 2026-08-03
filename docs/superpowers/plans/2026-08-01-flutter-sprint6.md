# Flutter Sprint 6 — Deep Linking Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Flutter app (mobile + desktop) openable from URLs —
`https://foxyads.app/...` via Android App Links + iOS Universal Links, and
`foxyads://...` for desktop + app-to-app — map the web's public paths to the
app's screens, and emit real canonical URLs from Share.

**Architecture:** A pure `resolveDeepLink(Uri)` resolver + a `DeepLinkService`
wiring the `app_links` package (initial + warm-start links) into the existing
`GoRouter`. Platform config (Android manifest, iOS/macOS Info.plist +
entitlements, Windows/Linux protocol). Generated domain-verification files the
user hosts on Vercel. A `siteUrl` helper mirroring the web's `src/lib/site.ts`.

**Tech Stack:** Flutter 3.44 / Dart 3.12, flutter_riverpod ^3, go_router ^17,
app_links ^6 (NEW), share_plus (present), url_launcher (present).

## Global Constraints

- Hosts claimed: `foxyads.app` + `foxyads.vercel.app` (App/Universal Links) +
  `foxyads://` scheme. Canonical share base = `https://foxyads.app`.
- Android applicationId `com.wildfoxy.foxy_ads`; iOS/macOS bundle
  `com.wildfoxy.foxyAds`.
- The ONLY path remap is `/anuncio/:id` → `/listing/:id`. All other public paths
  (`/agencia/:id`, `/promocion/:id`, `/promociones`, `/inmuebles-en[/:city]`,
  `/ayuda`, `/contacto`, `/privacidad`, `/terminos`) already match the app's
  routes and pass through unchanged.
- The resolver ONLY trusts our two https hosts + the `foxyads` scheme; any other
  host → home. Unknown/garbage path or non-UUID id on `/anuncio|/agencia|/promocion`
  → home. Never throw.
- `app_links` is the one new dependency (justified — new capability).
- The two verification files carry placeholders (`<RELEASE_SIGNING_SHA256>`,
  `<TEAMID>`) the USER fills; they are hosted by the user, not deployed here.
- `flutter analyze` 0 errors after every task. `flutter test` full suite green
  after every task. Do NOT run `flutter build apk` inside tasks (controller runs
  it at the final review). No functional change to Sprint 1–5 behavior.
- Flutter web is NOT a target — no `web/` deep-link work.

## File Structure

**Create**
- `lib/core/deeplink/deep_link_resolver.dart` — pure `resolveDeepLink(Uri) -> String?`.
- `lib/core/deeplink/deep_link_service.dart` — `DeepLinkService` + `deepLinkServiceProvider`.
- `lib/core/util/site_url.dart` — `siteUrl`, `listingUrl`, `agencyUrl`, `developmentUrl`.
- `deeplink/well-known/assetlinks.json` — Android App Links (user hosts).
- `deeplink/well-known/apple-app-site-association` — iOS Universal Links (user hosts).
- `deeplink/README.md` — hosting + fingerprint/TeamID + runtime-test instructions.
- `test/deep_link_resolver_test.dart`, `test/site_url_test.dart`.

**Modify**
- `pubspec.yaml` — add `app_links: ^6.x`.
- `lib/main.dart` — build the `GoRouter` so it's reachable by the service; init
  `DeepLinkService` after first frame; route initial + stream links.
- `lib/core/router/app_router.dart` — expose the `GoRouter` instance (a provider
  or a top-level) if not already reachable for `router.go(...)`.
- `android/app/src/main/AndroidManifest.xml` — 2 intent-filters.
- `ios/Runner/Info.plist` (+ `ios/Runner/Runner.entitlements`).
- `macos/Runner/Info.plist` (+ `macos/Runner/*.entitlements`).
- `windows/runner/*` + `linux/*` — protocol registration (documented; minimal code).
- `lib/features/listings/presentation/screens/listing_detail_screen.dart` — Share emits URL.
- `lib/l10n/app_{es,en,it}.arb` — `listingDetailShareMessage` gains a `{url}` placeholder.

---

## Task 1: Pure resolver + site_url helper + tests

**Files:**
- Create: `lib/core/deeplink/deep_link_resolver.dart`, `lib/core/util/site_url.dart`
- Test: `test/deep_link_resolver_test.dart`, `test/site_url_test.dart`

**Interfaces produced:**
```dart
// site_url.dart
String siteUrl(String path);         // 'https://foxyads.app' + path
String listingUrl(String id);        // '/anuncio/$id'   (web canonical path)
String agencyUrl(String id);         // '/agencia/$id'
String developmentUrl(String id);    // '/promocion/$id'
// deep_link_resolver.dart
String? resolveDeepLink(Uri uri);    // go_router location, or null -> caller sends home
```

- [ ] **Step 1: Write the failing tests.**

```dart
// test/site_url_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:foxy_ads/core/util/site_url.dart';

void main() {
  test('siteUrl joins base + path', () {
    expect(siteUrl('/anuncio/1'), 'https://foxyads.app/anuncio/1');
    expect(siteUrl('ayuda'), 'https://foxyads.app/ayuda');
    expect(siteUrl(''), 'https://foxyads.app');
  });
  test('canonical path helpers', () {
    expect(listingUrl('abc'), '/anuncio/abc');
    expect(agencyUrl('abc'), '/agencia/abc');
    expect(developmentUrl('abc'), '/promocion/abc');
  });
}
```

```dart
// test/deep_link_resolver_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:foxy_ads/core/deeplink/deep_link_resolver.dart';

const _uuid = '11111111-1111-1111-1111-111111111111';

void main() {
  group('resolveDeepLink https (our hosts)', () {
    test('anuncio -> /listing/:id', () {
      expect(resolveDeepLink(Uri.parse('https://foxyads.app/anuncio/$_uuid')),
          '/listing/$_uuid');
    });
    test('agencia / promocion pass through', () {
      expect(resolveDeepLink(Uri.parse('https://foxyads.app/agencia/$_uuid')),
          '/agencia/$_uuid');
      expect(resolveDeepLink(Uri.parse('https://foxyads.app/promocion/$_uuid')),
          '/promocion/$_uuid');
    });
    test('static + search pass through', () {
      for (final p in ['/ayuda', '/contacto', '/privacidad', '/terminos', '/promociones']) {
        expect(resolveDeepLink(Uri.parse('https://foxyads.app$p')), p);
      }
      expect(resolveDeepLink(Uri.parse('https://foxyads.app/inmuebles-en')), '/inmuebles-en');
      expect(resolveDeepLink(Uri.parse('https://foxyads.app/inmuebles-en/madrid')),
          '/inmuebles-en/madrid');
    });
    test('vercel fallback host also honored', () {
      expect(resolveDeepLink(Uri.parse('https://foxyads.vercel.app/anuncio/$_uuid')),
          '/listing/$_uuid');
    });
  });

  group('resolveDeepLink foxyads:// scheme', () {
    test('scheme host+path -> /listing/:id', () {
      expect(resolveDeepLink(Uri.parse('foxyads://anuncio/$_uuid')), '/listing/$_uuid');
    });
    test('scheme static', () {
      expect(resolveDeepLink(Uri.parse('foxyads://ayuda')), '/ayuda');
    });
  });

  group('resolveDeepLink guards -> null (caller sends home)', () {
    test('bad id', () {
      expect(resolveDeepLink(Uri.parse('https://foxyads.app/anuncio/not-a-uuid')), isNull);
    });
    test('unknown path', () {
      expect(resolveDeepLink(Uri.parse('https://foxyads.app/some/unknown')), isNull);
    });
    test('foreign host', () {
      expect(resolveDeepLink(Uri.parse('https://evil.com/anuncio/$_uuid')), isNull);
    });
    test('empty', () {
      expect(resolveDeepLink(Uri.parse('https://foxyads.app/')), isNull);
      expect(resolveDeepLink(Uri.parse('https://foxyads.app')), isNull);
    });
  });
}
```

- [ ] **Step 2: Run — expect FAIL.**

- [ ] **Step 3: Implement `site_url.dart`.**

```dart
// lib/core/util/site_url.dart
const String siteBase = 'https://foxyads.app';

String siteUrl(String path) {
  if (path.isEmpty) return siteBase;
  return path.startsWith('/') ? '$siteBase$path' : '$siteBase/$path';
}

String listingUrl(String id) => '/anuncio/$id';
String agencyUrl(String id) => '/agencia/$id';
String developmentUrl(String id) => '/promocion/$id';
```

- [ ] **Step 4: Implement `deep_link_resolver.dart`.**

```dart
// lib/core/deeplink/deep_link_resolver.dart
const _trustedHosts = {'foxyads.app', 'foxyads.vercel.app'};
const _scheme = 'foxyads';

final _uuidRe = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

/// Maps an incoming deep-link [uri] to a go_router location, or null when the
/// caller should fall back to home. Only our https hosts + the foxyads scheme
/// are honored. The only real remap is /anuncio/:id -> /listing/:id.
String? resolveDeepLink(Uri uri) {
  // Normalize the path across the two link forms.
  final String path;
  if (uri.scheme == 'https' && _trustedHosts.contains(uri.host)) {
    path = uri.path;
  } else if (uri.scheme == _scheme) {
    // foxyads://anuncio/123  -> host='anuncio', path='/123'  -> '/anuncio/123'
    path = '/${uri.host}${uri.path}';
  } else {
    return null; // foreign host / scheme
  }

  final segments = path.split('/').where((s) => s.isNotEmpty).toList();
  if (segments.isEmpty) return null;

  bool isId(String s) => _uuidRe.hasMatch(s);

  switch (segments[0]) {
    case 'anuncio':
      if (segments.length == 2 && isId(segments[1])) return '/listing/${segments[1]}';
      return null;
    case 'agencia':
      if (segments.length == 2 && isId(segments[1])) return '/agencia/${segments[1]}';
      return null;
    case 'promocion':
      if (segments.length == 2 && isId(segments[1])) return '/promocion/${segments[1]}';
      return null;
    case 'promociones':
      return segments.length == 1 ? '/promociones' : null;
    case 'inmuebles-en':
      if (segments.length == 1) return '/inmuebles-en';
      if (segments.length == 2) return '/inmuebles-en/${segments[1]}';
      return null;
    case 'ayuda':
    case 'contacto':
    case 'privacidad':
    case 'terminos':
      return segments.length == 1 ? '/${segments[0]}' : null;
    default:
      return null;
  }
}
```

> Implementer: cross-check every returned location against
> `lib/core/router/app_router.dart` — each must be a REGISTERED route path
> (`/listing/:id`, `/agencia/:id`, `/promocion/:id`, `/promociones`,
> `/inmuebles-en`, `/inmuebles-en/:city`, `/ayuda`, `/contacto`, `/privacidad`,
> `/terminos`). If any differs (e.g. the app uses `/inmuebles-en/:city` vs a
> different param name, or the listing route is `/anuncio/:id` already), adjust
> the mapping to the REAL registered paths and update the test expectations to
> match. The test is the contract; the real routes are the ground truth.

- [ ] **Step 5: Run tests — PASS. `flutter analyze` (0 errors). Commit.**

```bash
git add -A && git commit -m "feat(deeplink): pure resolver + site_url helpers"
```

---

## Task 2: DeepLinkService + wire into main.dart

**Files:**
- Create: `lib/core/deeplink/deep_link_service.dart`
- Modify: `pubspec.yaml` (add `app_links`), `lib/main.dart`, `lib/core/router/app_router.dart` (expose the router if needed)

**Interfaces produced:** `DeepLinkService` (init + dispose), `deepLinkServiceProvider`; deep links navigate the running app.

- [ ] **Step 1: Add `app_links` to `pubspec.yaml`** (`app_links: ^6.3.0` or latest 6.x). Run `flutter pub get`.

- [ ] **Step 2: Ensure the `GoRouter` is reachable for navigation.** Read
  `app_router.dart` + `main.dart`. The service needs to call `router.go(location)`.
  If the router is already a top-level `final` or a provider, use it. Otherwise
  expose it (a `routerProvider` or a top-level `final appRouter = GoRouter(...)`).
  Prefer the least invasive option that fits the current structure.

- [ ] **Step 3: Implement `DeepLinkService`.**

```dart
// lib/core/deeplink/deep_link_service.dart
import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'deep_link_resolver.dart';

class DeepLinkService {
  DeepLinkService(this._router);
  final GoRouter _router;
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;

  /// Cold-start: resolve the launch link (if any) once the app is up.
  Future<void> handleInitialLink() async {
    final uri = await _appLinks.getInitialLink();
    if (uri != null) _navigate(uri);
  }

  /// Warm-start: listen for links while the app runs.
  void startListening() {
    _sub = _appLinks.uriLinkStream.listen(_navigate, onError: (_) {});
  }

  void _navigate(Uri uri) {
    final location = resolveDeepLink(uri);
    // null -> fall back to home so a bad/foreign link never dead-ends.
    _router.go(location ?? '/');
  }

  void dispose() => _sub?.cancel();
}

final deepLinkServiceProvider = Provider<DeepLinkService>((ref) {
  // The router instance is provided by main.dart's wiring (see below).
  throw UnimplementedError('override deepLinkServiceProvider with the app router');
});
```

> The provider is a placeholder overridden in `main.dart` where the concrete
> `GoRouter` exists (or construct the service directly in `main.dart` and hold
> it in state). Whichever fits — the key contract: `handleInitialLink()` runs
> once after the first frame, `startListening()` runs for the app's lifetime,
> both route through `resolveDeepLink` + `router.go`.

- [ ] **Step 4: Wire into `main.dart`.** Read the current `main.dart`
  (`MyApp extends ConsumerWidget` from Sprint 5). After the router is built,
  construct the `DeepLinkService(router)`, and in the app's init (e.g. a
  `ConsumerStatefulWidget` `initState` + `WidgetsBinding.instance.addPostFrameCallback`)
  call `handleInitialLink()` + `startListening()`. If `MyApp` is a
  `ConsumerWidget`, convert the shell to a `ConsumerStatefulWidget` to own the
  service lifecycle (init once, dispose on teardown). Keep the Sprint-5 locale
  wiring intact.

- [ ] **Step 5: `flutter analyze` (0 errors) + `flutter test` (green — no new
  test here; the service is exercised by manual adb/simctl runs documented in
  F4's README, and the resolver is already unit-tested). Commit.**

```bash
git add -A && git commit -m "feat(deeplink): AppLinks service wired into app"
```

---

## Task 3: Android + iOS + macOS platform config

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `ios/Runner/Info.plist`, `ios/Runner/Runner.entitlements`
- Modify: `macos/Runner/Info.plist`, `macos/Runner/*.entitlements`

- [ ] **Step 1: Android** — add the two intent-filters (App Links autoverify
  https for `foxyads.app` + `foxyads.vercel.app`, and the `foxyads` custom
  scheme) to the main `<activity>` in `AndroidManifest.xml`, alongside the
  existing MAIN/LAUNCHER filter. Use the exact XML from the spec.

- [ ] **Step 2: iOS** — in `ios/Runner/Info.plist` add `CFBundleURLTypes` with a
  `CFBundleURLSchemes` array containing `foxyads`. In
  `ios/Runner/Runner.entitlements` (create if absent) add
  `com.apple.developer.associated-domains` = `[applinks:foxyads.app,
  applinks:foxyads.vercel.app]`.

- [ ] **Step 3: macOS** — same as iOS: `macos/Runner/Info.plist` CFBundleURLTypes
  with `foxyads`, and the associated-domains entitlement in the macOS entitlements
  files (`DebugProfile.entitlements` + `Release.entitlements`).

- [ ] **Step 4: `flutter analyze` (0 errors) + `flutter test` (green). Commit.**
  (Platform XML/plist changes don't affect the Dart analyzer/tests, but run both
  to confirm nothing regressed.)

```bash
git add -A && git commit -m "feat(deeplink): Android/iOS/macOS platform config"
```

---

## Task 4: Windows + Linux registration + verification files + README

**Files:**
- Modify: `windows/runner/*` (protocol registration — minimal), `linux/*` (.desktop MimeType)
- Create: `deeplink/well-known/assetlinks.json`, `deeplink/well-known/apple-app-site-association`, `deeplink/README.md`

- [ ] **Step 1: Windows** — register the `foxyads` URL protocol. The robust,
  low-risk approach: document the registry keys in `deeplink/README.md` AND, if
  `app_links` provides a runner snippet, add it. At minimum ship the README
  instructions; the plugin receives the launch argv. Do NOT over-engineer the
  runner.

- [ ] **Step 2: Linux** — add a `.desktop` entry (or document it) with
  `MimeType=x-scheme-handler/foxyads;` + the `xdg-mime default` registration
  step in the README.

- [ ] **Step 3: Generate `assetlinks.json`** (`deeplink/well-known/`):

```json
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "com.wildfoxy.foxy_ads",
      "sha256_cert_fingerprints": ["REPLACE_WITH_RELEASE_SIGNING_SHA256"]
    }
  }
]
```

- [ ] **Step 4: Generate `apple-app-site-association`** (NO file extension):

```json
{
  "applinks": {
    "details": [
      {
        "appID": "REPLACE_WITH_TEAMID.com.wildfoxy.foxyAds",
        "paths": [
          "/anuncio/*", "/agencia/*", "/promocion/*", "/promociones",
          "/inmuebles-en", "/inmuebles-en/*",
          "/ayuda", "/contacto", "/privacidad", "/terminos"
        ]
      }
    ]
  }
}
```

- [ ] **Step 5: Write `deeplink/README.md`** — cover: (a) WHERE to host
  (`foxyads_web/public/.well-known/` → served at
  `https://foxyads.app/.well-known/assetlinks.json` and
  `/.well-known/apple-app-site-association`, `Content-Type: application/json`,
  no redirect; Vercel serves `public/` at root); (b) HOW to get the release
  SHA-256 (`cd android && ./gradlew signingReport`, copy the SHA-256 of the
  release variant; or `keytool -list -v -keystore <release.jks> -alias <alias>`);
  (c) HOW to find the Apple Team ID (Apple Developer portal → Membership);
  (d) the two placeholders to replace; (e) that `foxyads://` works WITHOUT any of
  this; (f) runtime testing:
  `adb shell am start -a android.intent.action.VIEW -d "https://foxyads.app/anuncio/<uuid>"`
  and `adb shell am start -W -a android.intent.action.VIEW -d "foxyads://anuncio/<uuid>"`,
  iOS `xcrun simctl openurl booted "foxyads://anuncio/<uuid>"`.

- [ ] **Step 6: `flutter analyze` (0 errors) + `flutter test` (green). Commit.**

```bash
git add -A && git commit -m "feat(deeplink): desktop protocol + hosted verification files + README"
```

---

## Task 5: Share emits canonical URLs

**Files:**
- Modify: `lib/features/listings/presentation/screens/listing_detail_screen.dart`
- Modify: `lib/l10n/app_{es,en,it}.arb` (`listingDetailShareMessage` gains `{url}`)
- Modify (if a share affordance exists): agency profile + development detail screens

- [ ] **Step 1: Update the ARB** `listingDetailShareMessage` to include a `{url}`
  placeholder in all three locales. Current es value:
  `"{title} - {price}\n\nMira este anuncio en Foxy Ads"` →
  `"{title} - {price}\n\nMira este anuncio en Foxy Ads: {url}"`. Add `url` to the
  `@listingDetailShareMessage` placeholders (type String). Mirror en/it. Run
  `flutter gen-l10n`.

- [ ] **Step 2: Update the listing Share call** in `listing_detail_screen.dart`
  to pass `siteUrl(listingUrl(listing.id))` as the `url` arg:
  `Share.share(l10n.listingDetailShareMessage(listing.title, listing.formattedPrice, siteUrl(listingUrl(listing.id))))`.
  Import `site_url.dart`.

- [ ] **Step 3: Agency + development share (only if a Share button already
  exists on those screens).** Grep the agency profile + development detail
  screens for an existing `Share.share`/`SharePlus`. If present, include
  `siteUrl(agencyUrl(id))` / `siteUrl(developmentUrl(id))` similarly (add ARB
  keys if needed). If NO share affordance exists there, do NOT add one — that's
  out of scope for this task (keep it to wiring the URL into existing shares).

- [ ] **Step 4: `flutter analyze` (0 errors) + `flutter test` (green — update any
  test asserting the old share message). Commit.**

```bash
git add -A && git commit -m "feat(deeplink): Share emits canonical foxyads.app URLs"
```

---

## Task 6: Final whole-branch review

- [ ] **Step 1: `flutter analyze` + `flutter test` + `flutter build apk --debug`
  (controller runs the build).**
- [ ] **Step 2: Generate the review package** (`scripts/review-package MERGE_BASE HEAD`).
- [ ] **Step 3: Dispatch ONE final code reviewer** (most capable model) with the
  package + the spec's attention lens. Checks: resolver only trusts our hosts +
  scheme (no open-redirect / foreign-host navigation); every resolved location is
  a REAL registered route; the service routes both cold + warm start; the manifest/
  plist/entitlements are well-formed; the verification files have the right
  package/bundle + the documented placeholders; the Share emits the canonical URL;
  no new dependency beyond `app_links`; Sprint 1–5 behavior intact.
- [ ] **Step 4: If Critical/Important findings, dispatch ONE fix subagent with the
  full list. Otherwise DONE — record + update memory.**

---

## Self-Review (author)

- **Spec coverage:** resolver + site_url (T1), service + wiring (T2), Android/iOS/
  macOS config (T3), Windows/Linux + verification files + README (T4), Share URLs
  (T5), review (T6). ✓
- **Type consistency:** `resolveDeepLink(Uri) -> String?` and the `siteUrl`/
  `listingUrl`/… helpers are defined once (T1) and consumed by the service (T2)
  and the Share (T5). The service holds a `GoRouter` and calls `.go`.
- **Placeholder scan:** the two verification-file placeholders
  (`REPLACE_WITH_RELEASE_SIGNING_SHA256`, `REPLACE_WITH_TEAMID`) are INTENTIONAL
  (user fills them) and documented in the README — not plan-placeholders. Every
  code step has real code; the resolver has full test coverage.
- **Security:** the resolver's host allow-list is the security boundary (foreign
  host → home); bad-id guard prevents pushing a screen that errors; null → home
  so no dead-end.