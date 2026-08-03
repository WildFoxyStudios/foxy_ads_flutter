# Flutter Sprint 6 — Deep Linking (Design)

**Date:** 2026-08-01
**Status:** Approved (verbal — "Completo: URLs web + escritorio")
**Scope:** Make the Flutter app (mobile + desktop; NOT web) openable from URLs:
`https://foxyads.app/...` web links open the app via Android App Links + iOS
Universal Links, and a `foxyads://` custom scheme covers desktop + app-to-app.
Map the web's public paths to the app's screens, and fix Share to emit real
canonical URLs. Builds on Sprints 1–5.

## Goal

Close the deep-linking gap the parity effort missed: (1) a shared/pasted
`https://foxyads.app/anuncio/<id>` (or `/agencia/<id>`, `/promocion/<id>`, a
static page) opens the corresponding screen in the installed app instead of the
browser; (2) desktop + app-to-app links use `foxyads://<path>`; (3) the Share
buttons emit the real canonical web URL (today they share text with no link).

## Non-goals

- The Flutter web target (`web/` exists only because Flutter scaffolds it; it is
  NOT a shipping platform — no web deep-link work).
- Changing the web app. The two domain-verification files are GENERATED here for
  the user to host on Vercel (`foxyads_web/public/.well-known/`); this repo does
  not deploy them.
- Locale-prefixed URL routing (the web's `as-needed` locale prefix). Native apps
  don't use URL-based locale; the app's locale is the in-app `localeProvider`
  (Sprint 5). Incoming links are locale-agnostic paths.

## URL contract

**Hosts / schemes the app claims:**
- `https://foxyads.app/*` — App Links (Android) + Universal Links (iOS).
- `https://foxyads.vercel.app/*` — same (the SITE_URL fallback; listed so
  links on the preview domain also open the app).
- `foxyads://*` — custom scheme (desktop protocol handler + app-to-app +
  QR/notification links).

**Path → screen mapping** (a single resolver maps an incoming path to a
go_router location; unknown paths fall back to home):

| Incoming path (web canonical) | App screen / go_router location |
|---|---|
| `/anuncio/:id` | listing detail — remap to the app's `/listing/:id` |
| `/agencia/:id` | agency profile — `/agencia/:id` (already same) |
| `/promocion/:id` | development detail — `/promocion/:id` (already same) |
| `/promociones` | developments index — `/promociones` (already same) |
| `/inmuebles-en` and `/inmuebles-en/:city` | RE search / city landing (same) |
| `/ayuda` `/contacto` `/privacidad` `/terminos` | static pages (same, Sprint 5) |
| anything else / unmapped | home (`/`) — graceful, never a crash |

`/anuncio/:id` is the ONLY genuine remap (the app's internal listing route is
`/listing/:id`). Everything else already shares the web's path, so the resolver
is mostly a pass-through plus the one alias.

For the `foxyads://` scheme, the URI's `host + path` is treated as the path:
`foxyads://anuncio/123` → path `/anuncio/123` → the same resolver. (i.e. the
scheme's "host" segment is the first path component.)

## Architecture

**New dependency: `app_links` (^6).** go_router consumes the *initial* platform
route and, on mobile, OS-delivered App/Universal Links via its default
`RouteInformationProvider` — but reliable **warm-start** links (app already
running) and **desktop custom-scheme** delivery need the `app_links` package
(the maintained de-facto standard). This is a justified new dependency for a new
capability (the "no new dependencies" rule was a per-sprint constraint on the
parity sprints, not a project law). Everything else is platform config + a pure
resolver + wiring.

**Components:**

1. `lib/core/deeplink/deep_link_resolver.dart` — a PURE function
   `String? resolveDeepLink(Uri uri)` returning the go_router location for an
   incoming `Uri` (from either an `https://foxyads.app/...` link or a
   `foxyads://...` link), or `null` when it should fall back to home. Pure →
   unit-testable with no platform.
   - Normalizes: for `https`, use `uri.path`; for `foxyads` scheme, reconstruct
     the path as `/${uri.host}${uri.path}` (host is the first segment).
   - Applies the mapping table above. Validates `:id` segments look like UUIDs
     for `/anuncio`, `/agencia`, `/promocion` (else → home) so a garbage id
     doesn't push a screen that immediately errors.

2. `lib/core/deeplink/deep_link_service.dart` — a thin service that wires
   `app_links`:
   - On startup: `AppLinks().getInitialLink()` → if present, resolve + navigate
     (after the router is ready).
   - A stream subscription `AppLinks().uriLinkStream.listen(...)` for warm-start
     links → resolve + `router.go(location)`.
   - Exposes `deepLinkServiceProvider` (Riverpod) initialized in `main.dart`
     after the `GoRouter` is built. Navigation uses the existing router instance
     (a `GlobalKey<NavigatorState>` or the `GoRouter` held in a provider).
   - Errors (malformed URI, resolver returns null) → navigate home, never throw.

3. `lib/core/util/site_url.dart` — `siteUrl(String path)` mirroring the web's
   `src/lib/site.ts`: a single `const _siteBase = 'https://foxyads.app'` +
   `String siteUrl(String path) => path.startsWith('/') ? '$_siteBase$path' :
   '$_siteBase/$path'`. Also `listingUrl(id)`, `agencyUrl(id)`,
   `developmentUrl(id)` convenience helpers building the CANONICAL WEB paths
   (`/anuncio/:id`, `/agencia/:id`, `/promocion/:id`).

4. **go_router:** add an ALIAS route `/anuncio/:id` that builds the same
   `ListingDetailScreen` as `/listing/:id` (so an incoming web-path link resolves
   without a redirect hop). The resolver already remaps, but registering the
   alias keeps `router.go('/anuncio/:id')` valid and lets the deep-link path be
   used verbatim. (Alternatively the resolver rewrites `/anuncio/:id` →
   `/listing/:id` and no alias is needed — pick the rewrite approach to avoid a
   duplicate route: the resolver returns `/listing/$id`. This is cleaner; NO new
   go_router route needed.)

5. **Share fix:** every Share button emits the canonical URL:
   - Listing (`listing_detail_screen.dart`): message becomes
     `"{title} - {price}\n\n{url}"` where `url = siteUrl(listingUrl(id))`. Add a
     `{url}` placeholder to the `listingDetailShareMessage` ARB key (es/en/it).
   - Agency profile + development detail: add a Share affordance (if not present)
     or, where a share already exists, include `agencyUrl(id)` /
     `developmentUrl(id)`. (Scope: at minimum the listing share, which exists
     today; agency/development share are added if the screens have a share
     button — verify.)

## Platform configuration (generated + committed)

**Android** (`android/app/src/main/AndroidManifest.xml`) — add TWO intent-filters
to the main activity (alongside the existing MAIN/LAUNCHER):
- App Links (autoverified https):
  ```xml
  <intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW"/>
    <category android:name="android.intent.category.DEFAULT"/>
    <category android:name="android.intent.category.BROWSABLE"/>
    <data android:scheme="https" android:host="foxyads.app"/>
    <data android:scheme="https" android:host="foxyads.vercel.app"/>
  </intent-filter>
  ```
- Custom scheme:
  ```xml
  <intent-filter>
    <action android:name="android.intent.action.VIEW"/>
    <category android:name="android.intent.category.DEFAULT"/>
    <category android:name="android.intent.category.BROWSABLE"/>
    <data android:scheme="foxyads"/>
  </intent-filter>
  ```

**iOS** (`ios/Runner/Info.plist` + entitlements):
- `CFBundleURLTypes` with `CFBundleURLSchemes = [foxyads]`.
- `ios/Runner/Runner.entitlements`: `com.apple.developer.associated-domains =
  [applinks:foxyads.app, applinks:foxyads.vercel.app]`.

**macOS** (`macos/Runner/Info.plist` + entitlements):
- `CFBundleURLTypes` with `foxyads` scheme.
- Associated domains entitlement for `applinks:` (Universal Links on macOS).

**Windows** (`windows/runner`): register the `foxyads://` protocol. Simplest
robust path: `app_links` documents a runner-side registration; add the
`foxyads` URL scheme via the app's registry entry on first run (documented in
`deeplink/README.md`). At minimum, document the registry keys; the `app_links`
plugin receives the argv link on launch.

**Linux** (`linux/`): a `.desktop` entry with
`MimeType=x-scheme-handler/foxyads;` + `xdg-mime` registration, documented in
`deeplink/README.md`.

**Domain-verification files (GENERATED here, USER hosts on Vercel):**
`deeplink/well-known/assetlinks.json` and
`deeplink/well-known/apple-app-site-association` + a `deeplink/README.md` with
step-by-step hosting instructions.
- `assetlinks.json`:
  ```json
  [{
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "com.wildfoxy.foxy_ads",
      "sha256_cert_fingerprints": ["<RELEASE_SIGNING_SHA256 — see README>"]
    }
  }]
  ```
- `apple-app-site-association` (no extension, `application/json`):
  ```json
  {"applinks":{"details":[{"appID":"<TEAMID>.com.wildfoxy.foxyAds","paths":["/anuncio/*","/agencia/*","/promocion/*","/promociones","/inmuebles-en*","/ayuda","/contacto","/privacidad","/terminos"]}]}}
  ```
- `README.md`: how to get the release SHA-256 (`./gradlew signingReport` or
  `keytool -list -v -keystore <release.keystore>`), how to find the Apple Team
  ID, WHERE to put the files (`foxyads_web/public/.well-known/`, served at
  `https://foxyads.app/.well-known/assetlinks.json` with `Content-Type:
  application/json` and no redirect), and that Vercel serves `public/` at the
  root. NOTE the two placeholders (`<RELEASE_SIGNING_SHA256>`, `<TEAMID>`) MUST
  be filled by the user — App/Universal Link verification fails silently
  otherwise (the `foxyads://` scheme still works meanwhile).

## Testing

- `test/deep_link_resolver_test.dart` — the pure resolver:
  - `https://foxyads.app/anuncio/<uuid>` → `/listing/<uuid>`.
  - `foxyads://anuncio/<uuid>` → `/listing/<uuid>`.
  - `https://foxyads.app/agencia/<uuid>` → `/agencia/<uuid>`.
  - `https://foxyads.app/promocion/<uuid>` → `/promocion/<uuid>`.
  - `https://foxyads.app/ayuda` → `/ayuda`; same for contacto/privacidad/terminos.
  - `https://foxyads.app/inmuebles-en/madrid` → `/inmuebles-en/madrid`.
  - `https://foxyads.app/anuncio/not-a-uuid` → home (`/`) (bad id guard).
  - `https://foxyads.app/some/unknown/path` → home.
  - `https://evil.com/anuncio/<uuid>` → home (host not ours) — the resolver only
    trusts our hosts + the `foxyads` scheme.
- `test/site_url_test.dart` — `siteUrl`/`listingUrl`/`agencyUrl`/`developmentUrl`
  build the exact canonical strings (`https://foxyads.app/anuncio/<id>` etc.).
- Manual per phase: `flutter analyze` 0 errors, `flutter test` green,
  `flutter build apk --debug` builds. Runtime deep-link testing (adb `am start`
  / `xcrun simctl openurl`) documented in `deeplink/README.md` for the user.

## Phased plan (one spec, phased plan, sequential SDD)

- **F1** — `app_links` dep + `deep_link_resolver.dart` (pure) + `site_url.dart`
  + their tests. No platform wiring yet.
- **F2** — `deep_link_service.dart` + wire into `main.dart` (initial + warm-start
  links → resolver → router.go); router held so navigation works.
- **F3** — Android + iOS + macOS platform config (manifest intent-filters,
  Info.plist URL types, entitlements).
- **F4** — Windows + Linux protocol registration + the generated
  `deeplink/well-known/*` files + `deeplink/README.md` (hosting + fingerprint
  instructions).
- **F5** — Share fix: emit canonical URLs from the listing (and agency/
  development if a share affordance exists) + the ARB `{url}` placeholder.
- **F6** — Final verification + whole-branch review.

## Out of scope

- Deferred-deep-link / install-attribution (open-after-install-from-store).
- Short links / branded link service.
- Server-side changes beyond the two static verification files the user hosts.

## Risks

- **App/Universal Link verification needs real signing fingerprints + Team ID +
  hosted files.** Mitigation: the `foxyads://` scheme works WITHOUT any of that
  (verified in-app), so deep linking is functional immediately; the https
  auto-verify lights up once the user hosts the files with the real
  fingerprint/TeamID. The README makes the two placeholders and the hosting
  steps explicit.
- **Warm-start vs cold-start navigation timing.** Mitigation: cold-start uses
  `getInitialLink()` resolved AFTER the router is ready; warm-start uses the
  stream. Both route through the same resolver + `router.go`.
- **A malicious/unowned host** trying to phish via a link. Mitigation: the
  resolver only honors our two hosts + the `foxyads` scheme; any other host →
  home.
- **Desktop protocol registration is finicky per-OS.** Mitigation: `app_links`
  handles receipt; registration is documented; if a platform's registration
  isn't wired, that platform simply doesn't receive links (no crash) and mobile
  is unaffected.