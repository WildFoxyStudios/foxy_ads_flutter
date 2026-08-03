# Flutter Sprint 8 — Auth + UX + Deeplink coverage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close audit gaps 🟠 D.2.1 (email-verification gate), 🟡 D.3 (dark
mode real), 🟡 D.3 (friendly error-builder), and 🟡 D.3 (deeplink coverage
for 5 more web paths).

**Architecture:** Email-verification gate via `authState.emailConfirmedAt`
+ new `/verify-email` route + banner in create/edit screens. Dark mode via
`themeModeProvider` Notifier + `AppTheme.darkTheme` + Settings tile.
Error-builder via a reusable `ErrorView` widget. Deeplinks via the existing
`resolveDeepLink` extended with 5 more paths (no new screens).

**Tech Stack:** Flutter 3.44 / Dart 3.12, flutter_riverpod ^3, go_router ^17,
supabase_flutter ^2, shared_preferences ^2.

## Global Constraints

- No new dependencies.
- All UI strings via `l10n.*` — no hardcoded Spanish.
- `flutter analyze` 0 errors after every task.
- `flutter test` — full suite green after every task (currently 105 tests).
- Do NOT run `flutter build apk` (controller runs at the end).
- The 3 uncommitted USER WIP files (firebase.json, firebase_options.dart,
  android/app/google-services.json) MUST NEVER be touched or staged.
- Use ONLY targeted `git add` — NEVER `git add -A`.

## File Structure

**Create**
- `lib/features/auth/presentation/screens/verify_email_screen.dart`
- `lib/core/theme/app_theme.dart` (extract existing `AppTheme.lightTheme`
  + add `AppTheme.darkTheme`)
- `lib/core/theme/theme_mode_provider.dart` (Notifier with persistence)
- `lib/core/widgets/error_view.dart`
- `test/auth_verify_email_test.dart` + `test/theme_mode_test.dart` +
  `test/error_view_test.dart` + extend `test/deep_link_resolver_test.dart`
  with 5 new path cases × 2 schemes.

**Modify**
- `lib/core/services/auth_service.dart` — add `resendVerificationEmail(String
  email)` calling `_supabase.auth.resend(...)` with type `signup` (no
  password).
- `lib/main.dart` — wire `themeMode: ref.watch(themeModeProvider)`,
  `darkTheme: AppTheme.darkTheme`. Extract the existing `AppTheme` from
  `main.dart` into the new `app_theme.dart` (don't lose existing tokens).
- `lib/core/router/app_router.dart` — register `/verify-email` route +
  replace `errorBuilder` raw text with `ErrorView`.
- `lib/core/deeplink/deep_link_resolver.dart` — extend with 5 new
  accepted paths.
- `lib/features/auth/presentation/screens/login_screen.dart` — when the
  signed-in user's `emailConfirmedAt == null` AND they're navigating to
  a protected route (create/edit), push to `/verify-email` first.
- `lib/features/listings/presentation/screens/create_listing_screen.dart` +
  `lib/features/developments/presentation/screens/development_form_screen.dart`
  — show a soft banner at the top when unverified; on submit, push to
  `/verify-email` if still unverified.
- `lib/features/settings/presentation/screens/settings_screen.dart` — replace
  the "coming soon" theme tile with a real theme picker.
- `lib/l10n/app_{es,en,it}.arb` — new keys for verify-email screen,
  theme picker, error view fallback.

---

## Task 1: email-verification gate — auth service + verify-email screen + banner

**Files:** create verify_email_screen.dart + auth service extension + ARB
keys + tests; modify create_listing_screen + development_form_screen + login_screen.

- [ ] **Step 1: Add `resendVerificationEmail` to `auth_service.dart`.**

```dart
Future<void> resendVerificationEmail(String email) async {
  try {
    await _supabase.auth.resend(type: OtpType.email, email: email);
  } catch (e) {
    throw Exception('Could not resend verification email: $e');
  }
}
```

- [ ] **Step 2: ARB keys** (es template):

```json
"authVerifyEmailRequired": "Verifica tu correo",
"authVerifyEmailBody": "Necesitas verificar tu correo electrónico antes de publicar. Te enviamos un email — revisa tu bandeja.",
"authVerifyEmailResend": "Reenviar email de verificación",
"authVerifyEmailResent": "Email enviado. Revisa tu bandeja.",
"authVerifyEmailResendError": "No se pudo reenviar el email. Inténtalo más tarde.",
"authVerifyEmailBanner": "Tu correo aún no está verificado. No podrás publicar hasta verificarlo.",
"authVerifyEmailCta": "Verificar correo",
"authVerifyEmailSignedInAs": "Sesión iniciada como {email}"
```

Plus the `@key` metadata blocks for `authVerifyEmailSignedInAs` with
`{email}` String placeholder.

- [ ] **Step 3: Build `VerifyEmailScreen`** (`ConsumerStatefulWidget`):
  - Reads `authStateProvider` to get current user; redirects to `/login`
    if not signed in.
  - Body: a "Sent to {email}" explanation + a "Resend" button (debounced
    60s — last-sent timestamp in `SharedPreferences` key
    `'verify_email_last_sent'` with the same auth email).
  - Spanish copy from the new ARB keys.

- [ ] **Step 4: Add route `/verify-email`** in `app_router.dart`:

```dart
static const verifyEmail = '/verify-email';
// in route list (after the static pages):
GoRoute(path: AppRoutes.verifyEmail, builder: (c, s) => const VerifyEmailScreen()),
```

- [ ] **Step 5: Add the banner** in `create_listing_screen.dart` and
  `development_form_screen.dart`. When `authState.emailConfirmedAt == null`,
  show a dismissable (or persistent — your call) Material banner at the
  top with `l10n.authVerifyEmailBanner` text + a "Verificar correo" button
  pushing to `AppRoutes.verifyEmail`.
  On `_submit` (create) / `_save` (development form), BEFORE the actual
  save RPC: if `emailConfirmedAt == null`, push to `AppRoutes.verifyEmail`
  and return (don't save). Mirrors the web's soft gate.

- [ ] **Step 6: From `login_screen.dart`** — after sign-in succeeds, if
  `emailConfirmedAt == null` AND the redirect query param contains
  `?redirect=/create-listing` (or any protected route), push to
  `/verify-email` first. The simplest: after `_signInWithEmail` /
  `_signInWithGoogle`, check `emailConfirmedAt`; if null AND a redirect
  was passed, push to `/verify-email?redirect=...`. The verify-email
  screen reads the redirect and, on success, pushes to it.

- [ ] **Step 7: Tests** (`test/auth_verify_email_test.dart`):
  - `resendVerificationEmail` happy path: calls Supabase, no throw.
  - `resendVerificationEmail` throws on Supabase error.
  - `VerifyEmailScreen` reads auth state + renders the resend button.
  - `VerifyEmailScreen` after resend: shows "Email enviado" + debounces.
  - Gate: create_listing_screen on submit when `emailConfirmedAt == null`
    pushes to `/verify-email` (don't call the RPC).

- [ ] **Step 8: `flutter analyze` (0 errors) + `flutter test` green. Commit.**

```bash
git add -A && git commit -m "feat(auth): email-verification gate + verify-email screen"
```

Wait — `git add -A` is forbidden. Use TARGETED `git add` for ONLY the
files YOU changed in this task. The reminder applies to every commit.

## Task 2: Dark mode real — theme file + provider + Settings tile

**Files:** create `app_theme.dart` + `theme_mode_provider.dart` + tests;
modify `main.dart` + `settings_screen.dart`.

- [ ] **Step 1: Extract the existing `AppTheme.lightTheme`** from
  `main.dart` into `lib/core/theme/app_theme.dart` (preserve every
  existing token — same colors, same shapes). Add `AppTheme.darkTheme`
  with the surface/text inverted (the codebase uses Material 3 ColorScheme;
  build `ColorScheme.fromSeed(seedColor: AppColors.primary, brightness:
  Brightness.dark)` + override `surface: const Color(0xFF111418)` and
  `onSurface: const Color(0xFFE6E6E6)` for a custom dark theme).
  KEEP `AppColors` unchanged — most colors should work in both modes.

- [ ] **Step 2: `themeModeProvider`** (Notifier with persistence):

```dart
// lib/core/theme/theme_mode_provider.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _key = 'app_theme_mode';
  @override
  ThemeMode build() {
    _loadFromPrefs();
    return ThemeMode.system;
  }
  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_key);
    if (v == null) return;
    final parsed = ThemeMode.values.firstWhere(
      (m) => m.name == v, orElse: () => ThemeMode.system);
    if (parsed != state) state = parsed;
  }
  Future<void> set(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new);
```

- [ ] **Step 3: Wire in `main.dart`**:
  - Extract `AppTheme` references to the new file.
  - Add `themeMode: ref.watch(themeModeProvider)`, `darkTheme: AppTheme.darkTheme`,
    `theme: AppTheme.lightTheme`.

- [ ] **Step 4: Replace the Settings "coming soon" tile** in
  `settings_screen.dart` with a real theme picker. The simplest UI:
  3 ListTiles in a `ExpansionTile` or 3 `RadioListTile`s:
  - "Seguir el sistema" (System) — `ref.read(themeModeProvider.notifier).set(ThemeMode.system)`
  - "Claro" (Light) — `set(ThemeMode.light)`
  - "Oscuro" (Dark) — `set(ThemeMode.dark)`
  Use existing `l10n` keys (add new ones if needed:
  `settingsThemeLabel`, `settingsThemeSystem`, `settingsThemeLight`,
  `settingsThemeDark`).

- [ ] **Step 5: Quick smoke pass** — read the codebase for `Colors.white`
  / `Colors.black` literals in widgets; if any exist in a context that
  doesn't translate to dark theme (e.g. icon color on a colored card),
  flag in the report (don't fix in this task — separate cleanup). The
  audit indicates most usage goes through `AppColors` which is theme-aware.

- [ ] **Step 6: Tests** (`test/theme_mode_test.dart`):
  - Default is `ThemeMode.system`.
  - `set(ThemeMode.dark)` updates state + persists (rebuild → dark).
  - Restore from prefs: simulate `SharedPreferences.setMockInitialValues({'app_theme_mode': 'dark'})`, build container, expect dark.

- [ ] **Step 7: `flutter analyze` (0 errors) + `flutter test` green. Commit.**

```bash
git add <only the files you changed>
git commit -m "feat(theme): dark mode real + theme picker"
```

## Task 3: Friendly error-builder + 5 deeplink paths

**Files:** create `error_view.dart` + tests; modify `app_router.dart` +
resolver.

- [ ] **Step 1: Build `ErrorView`** (`StatelessWidget`):
  - Props: `title`, `message`, optional `onRetry` (a callback).
  - Renders a centered icon (warning amber) + title (h2) + message + a
    retry button (if `onRetry != null`).

- [ ] **Step 2: ARB keys** (es):

```json
"commonErrorFallbackTitle": "Algo salió mal",
"commonErrorFallbackBody": "No pudimos cargar esta página. Inténtalo de nuevo.",
"commonErrorFallbackBackHome": "Volver al inicio"
```

- [ ] **Step 3: Replace `errorBuilder`** in `app_router.dart` (top-level):

```dart
errorBuilder: (context, state) {
  return Scaffold(
    appBar: AppBar(title: Text(l.commonErrorFallbackTitle)),
    body: ErrorView(
      title: l.commonErrorFallbackTitle,
      message: l.commonErrorFallbackBody,
      onRetry: () => router.go('/'),
    ),
  );
}
```

- [ ] **Step 4: Extend the resolver** with 5 new paths (both `foxyads://`
  and `https://foxyads.app/...`):
  - `/promocionar/:listingId` → `/promote/:listingId`
  - `/perfil` → `/profile`
  - `/mis-anuncios` → `/my-listings`
  - `/favoritos` → `/favorites`
  - `/búsquedas-guardadas` → `/saved-searches`

  The slug `/búsquedas-guardadas` is non-ASCII — the resolver must
  preserve the encoding (per the Sprint-7 Uri? refactor, query strings
  + special chars are preserved; but path-level non-ASCII needs the
  parser to keep the encoding). Test that
  `Uri.parse('https://foxyads.app/búsquedas-guardadas').path` produces
  a Uri whose segments match what the switch expects. If the segment
  encoding mismatches (e.g. percent-encoded vs raw), add a fallback
  decode step.

- [ ] **Step 5: Extend the resolver tests** with 10 new cases (5 paths × 2
  schemes). Verify the slug handling.

- [ ] **Step 6: `flutter analyze` (0 errors) + `flutter test` green. Commit.**

```bash
git add <only the files you changed>
git commit -m "feat(ui): friendly error-builder + deeplinks for profile/my-listings/etc."
```

## Task 4: Whole-branch review + signed release APK

- [ ] **Step 1:** `flutter analyze` + `flutter test` (must be 0 errors /
  green). `flutter build apk --release --no-pub` (controller runs).
- [ ] **Step 2:** Generate the review package
  (`scripts/review-package MERGE_BASE HEAD` — MERGE_BASE = the sprint-8
  spec commit, `3ca3ca9`).
- [ ] **Step 3:** Dispatch ONE final code reviewer (most capable model)
  with the package + this plan's attention lens. Triage findings, dispatch
  ONE fix subagent if Critical/Important.
- [ ] **Step 4:** If clean, record Sprint 8 in the progress ledger +
  update the memory file.

---

## Self-Review (author)

- **Spec coverage:** every audit gap mapped to a task (email-verify, dark
  mode, error-builder, 5 deeplinks). ✓
- **Type consistency:** `themeModeProvider` mirrors `localeProvider` +
  `selectedCountryProvider` patterns from earlier sprints. ✓
- **No placeholders** beyond the unavoidable: the slug test
  (`/búsquedas-guardadas`) is the one area that depends on Dart's Uri
  behavior — task instructions handle the case.
- **Risk:** dark theme may surface existing `Colors.white`/`Colors.black`
  assumptions; flagged as "smoke pass" in T2 with a follow-up task note
  rather than fixing in-sprint.