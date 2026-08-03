# Foxy Ads deep linking — hosting, verification, desktop registration, testing

This directory is the handoff between the Flutter app's deep-link handling
(`lib/core/deeplink/deep_link_resolver.dart`, `deep_link_service.dart`, and
the Android/iOS/macOS platform config from Task 3) and the two things that
live **outside** the Flutter app: the files the web team hosts on
`https://foxyads.app`, and the Windows/Linux desktop protocol registration
that has no Flutter-managed equivalent of the mobile manifest/entitlements.

Scheme: `foxyads://`. Verified web hosts: `foxyads.app`, `foxyads.vercel.app`.
Recognized paths (see `deep_link_resolver.dart` for the authoritative list):
`/anuncio/:id`, `/agencia/:id`, `/promocion/:id`, `/promociones`,
`/inmuebles-en`, `/inmuebles-en/:city`, `/ayuda`, `/contacto`, `/privacidad`,
`/terminos`.

## 1. `foxyads://` works with zero hosting/fingerprints

The custom URL scheme (`foxyads://anuncio/<uuid>`) is registered directly in
each platform's app config (Android `AndroidManifest.xml` intent-filter,
iOS `Info.plist` `CFBundleURLTypes`, macOS entitlements/Info.plist — all done
in Task 3) and requires **no** web hosting, no SHA-256 fingerprint, no Team
ID. It works the moment the app is installed. The two files in
`well-known/` and everything about hosting/fingerprints below are **only**
needed for the `https://foxyads.app/...` Universal Links (iOS) / App Links
(Android) auto-verification flow, so that tapping a normal web link opens the
app instead of (or in addition to) the browser.

## 2. Where to host the verification files

Copy both files from `deeplink/well-known/` into the Next.js web project's
public folder so Vercel serves them at the domain root:

```
foxyads_web/public/.well-known/assetlinks.json
foxyads_web/public/.well-known/apple-app-site-association
```

Vercel serves everything under `public/` verbatim at the site root, so this
resolves to:

- `https://foxyads.app/.well-known/assetlinks.json`
- `https://foxyads.app/.well-known/apple-app-site-association`

Requirements for both, or verification silently fails:

- Served with **`Content-Type: application/json`** (Next.js/Vercel does this
  automatically for `.json`; for `apple-app-site-association`, which has
  **no file extension**, you may need to add an explicit header — e.g. a
  `headers()` entry in `next.config.js` matching
  `/.well-known/apple-app-site-association` with
  `Content-Type: application/json`, since some static hosts default
  extensionless files to `application/octet-stream`).
- **HTTP 200**, no redirect (no trailing-slash redirect, no locale redirect,
  no auth wall). Both Android and iOS verifiers refuse to follow redirects.
- Reachable over plain HTTPS on port 443, no custom port.
- `apple-app-site-association` must **not** have a `.json` extension — the
  filename is exactly `apple-app-site-association`, nothing appended.

## 3. Filling in the placeholders

Two placeholders must be replaced before verification will actually pass in
production. Until they're replaced, App/Universal Links degrade gracefully —
the browser opens instead of the app — while `foxyads://` keeps working
regardless.

### `REPLACE_WITH_RELEASE_SIGNING_SHA256` (assetlinks.json)

The SHA-256 certificate fingerprint of the **release** signing key for
`com.wildfoxy.foxy_ads`. Get it with either:

```bash
cd android && ./gradlew signingReport
```

Look for the `Variant: release` block and copy the `SHA-256` line (not the
SHA-1, not the debug variant). Or, directly from the keystore:

```bash
keytool -list -v -keystore <path/to/release.jks> -alias <key-alias>
```

Copy the `SHA256:` value. Paste it into `assetlinks.json` as a
colon-separated uppercase hex string, e.g.
`"14:6D:E9:83:C5:73:06:50:D8:EE:B9:95:2F:34:FC:64:16:A0:83:42:E6:1D:BE:A8:8A:04:96:B2:3F:CF:44:E5"`.
If you sign with multiple keys (e.g. Play App Signing re-signs the APK with
its own key), list **both** fingerprints in the `sha256_cert_fingerprints`
array — Play App Signing's fingerprint is the one that matters for
production installs from the Play Store (Play Console → Setup → App
integrity → App signing key certificate → SHA-256).

### `REPLACE_WITH_TEAMID` (apple-app-site-association)

Your 10-character Apple Developer Team ID. Find it at
[developer.apple.com](https://developer.apple.com/account) →
**Membership** → **Team ID**. The final `appID` value is
`<TEAMID>.com.wildfoxy.foxyAds` (note: the iOS bundle ID uses
`foxyAds`, capital A — confirm it matches `ios/Runner.xcodeproj`'s
`PRODUCT_BUNDLE_IDENTIFIER` exactly, since Apple's verifier does a literal
string match).

## 4. Runtime testing

### Android

Custom scheme:

```bash
adb shell am start -W -a android.intent.action.VIEW -d "foxyads://anuncio/<uuid>" com.wildfoxy.foxy_ads
```

HTTPS App Link:

```bash
adb shell am start -a android.intent.action.VIEW -d "https://foxyads.app/anuncio/<uuid>"
```

Check App Links auto-verification status (must show `verified` per domain,
not `legacy_failure` / `none`, for the `https://` form to skip the
disambiguation dialog):

```bash
adb shell pm get-app-links com.wildfoxy.foxy_ads
```

If it's not verified: confirm `assetlinks.json` is reachable and correct
(`curl -s https://foxyads.app/.well-known/assetlinks.json`), then force a
re-check with
`adb shell pm verify-app-links --re-verify com.wildfoxy.foxy_ads` (Android
12+).

### iOS (simulator)

```bash
xcrun simctl openurl booted "foxyads://anuncio/<uuid>"
xcrun simctl openurl booted "https://foxyads.app/anuncio/<uuid>"
```

Universal Links on a real device require the app to have been installed
after `apple-app-site-association` was live and correct (iOS caches the AASA
fetch at install time); reinstall after fixing the file if verification
doesn't seem to take.

### Windows / Linux

See sections 5 and 6 below, then launch the app's exe/binary with a
`foxyads://...` URI as the argument to simulate an OS-triggered launch, e.g.
on Windows: `foxy_ads.exe foxyads://anuncio/<uuid>` (the `app_links` plugin
reads the launch URI from argv on desktop).

## 5. Windows — registering the `foxyads` URL protocol

**This task ships documentation only** — no runner code changes. Rationale:
the `app_links` plugin already reads the launch URI from `argv` on Windows
(see `windows/runner/main.cpp`, which forwards
`GetCommandLineArguments()` into
`project.set_dart_entrypoint_arguments(...)`); what's missing is only the
Registry entry that tells Windows *which* installed `.exe` to launch for
`foxyads://` URIs, and writing that from C++ at first run means calling the
Win32 Registry API (`RegCreateKeyExW`/`RegSetValueExW`) with elevation and
uninstall-cleanup implications that don't belong in a minimal task — get it
wrong and every debug/release rebuild fights over `%LOCALAPPDATA%` install
paths and stale registry entries claiming the scheme. A packaging step
(installer or first-run helper script) is the appropriate place for this,
not the runner itself.

### Manual registration (development / testing)

Create a `.reg` file (adjust the path to your built `foxy_ads.exe`):

```reg
Windows Registry Editor Version 5.00

[HKEY_CURRENT_USER\Software\Classes\foxyads]
@="URL:Foxy Ads Protocol"
"URL Protocol"=""

[HKEY_CURRENT_USER\Software\Classes\foxyads\shell]

[HKEY_CURRENT_USER\Software\Classes\foxyads\shell\open]

[HKEY_CURRENT_USER\Software\Classes\foxyads\shell\open\command]
@="\"C:\\path\\to\\foxy_ads.exe\" \"%1\""
```

Apply it with:

```powershell
reg import foxyads.reg
```

(or double-click the `.reg` file). `HKEY_CURRENT_USER` requires no admin
rights and is sufficient for per-user testing; a production installer
(MSIX/Inno Setup/etc.) should write the equivalent under
`HKEY_CLASSES_ROOT` (or `HKLM\Software\Classes`) during install and remove it
on uninstall.

Verify it took by running, from a shell (not the app itself):

```powershell
Start-Process "foxyads://anuncio/00000000-0000-0000-0000-000000000000"
```

which should launch `foxy_ads.exe` with that URI as `argv[1]`.

### If a packaging step is added later

Prefer doing the registry write in whatever installer technology gets
adopted (MSIX manifests support declaring URL protocol activation natively
via `<uap:Extension Category="windows.protocol">`; Inno Setup /
WiX can write the same `HKCR\foxyads\shell\open\command` keys shown above as
part of the install script) rather than adding Win32 Registry calls to
`windows/runner/main.cpp`.

## 6. Linux — registering the `foxyads` URL protocol

Also documentation-only: Linux desktop deep-link registration is
distro/desktop-environment specific (it depends on a `.desktop` file being
installed somewhere `update-desktop-database` and `xdg-mime` can see, which
varies between a raw `flutter build linux` output tree, a `.deb`/`.rpm`
package, and a Flatpak/Snap sandbox) and out of scope for a minimal,
low-risk task.

Create a `.desktop` file (e.g. `foxy_ads.desktop`, installed to
`~/.local/share/applications/` for a per-user install, or
`/usr/share/applications/` system-wide by a package):

```ini
[Desktop Entry]
Name=Foxy Ads
Comment=Foxy Ads — classifieds & real estate
Exec=/path/to/foxy_ads %u
Icon=foxy_ads
Terminal=false
Type=Application
MimeType=x-scheme-handler/foxyads;
Categories=Network;
```

The `%u` in `Exec` is required — it's how the desktop environment passes the
`foxyads://...` URI as an argument (same argv path the `app_links` plugin
already reads on Linux).

Register it as the default handler for the scheme:

```bash
xdg-mime default foxy_ads.desktop x-scheme-handler/foxyads
```

Verify:

```bash
xdg-mime query default x-scheme-handler/foxyads
xdg-open "foxyads://anuncio/00000000-0000-0000-0000-000000000000"
```

If packaging for Linux later (`.deb`, Flatpak, Snap, AppImage +
`.desktop`), install the `.desktop` file as part of that package instead of
requiring the manual `xdg-mime` step — package managers normally trigger the
MIME/desktop database update automatically on install.
