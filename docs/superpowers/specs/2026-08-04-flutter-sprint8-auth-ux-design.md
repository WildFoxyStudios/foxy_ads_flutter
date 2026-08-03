# Flutter Sprint 8 — Auth verification + UX polish + Deeplink coverage (Design)

**Date:** 2026-08-04
**Status:** Approved (sweep spec — "TODO el reporte")
**Scope:** Close the remaining auth/UX polish gaps from the audit, before the
content/locales sprint. Specifically: email-verification gate (🟠 D.2.1),
dark mode real (🟡 D.3), go_router error-builder amigable (🟡 D.3), y
ampliar el resolver de deeplinks para cubrir 5 paths web más
(`/promocionar`, `/perfil`, `/mis-anuncios`, `/favoritos`,
`/búsquedas-guardadas`).

## Goal

After Sprint 8, the app:
- Refleja el gate de email-verified que la web aplica (manda al usuario a
  verificar antes de poder publicar).
- Tiene dark mode funcional (persiste en SharedPreferences, sin más
  "coming soon").
- Muestra una pantalla de error amigable cuando una ruta falla (en lugar
  de `Text('Error: ${state.error}')`).
- Acepta deeplinks a las 5 rutas internas que faltan (los usuarios que
  tocan un link promocional a "mis anuncios" desde una notificación
  abren la app en la pantalla correcta).

## Non-goals

- Locales extra (pt-BR, fr, de) — Sprint 9.
- Hardcoded Spanish residual en listings widgets — Sprint 9.
- Chat/mensajería — out of scope (web no tiene `/chat` route).
- Teams/roles — pausado en la web.
- Admin panel — out of scope.

## Architecture (per feature)

### 1. Email-verification gate (🟠 D.2.1)

**The web's enforcement:** project-level config + the sign-up flow
redirects unverified users to a "verify your email" page. The Flutter
client uses the same Supabase Auth; the project setting
`email_confirm = true` is what enforces it. After `signUpWithEmail`, the
web either auto-signs-in (if disabled) or shows a "check your email"
screen. The Flutter app currently auto-signs-in (T1/Sprint 1 wiring).

**Decision:** add an EXPLICIT gate at the publish/edit screens. If
`user.emailConfirmedAt == null`, show a banner + redirect to a
`/verify-email` route that explains + offers a "Reenviar verificación"
button calling `authService.resendVerificationEmail(email)`.

**New ARB keys:** `authVerifyEmailRequired`, `authVerifyEmailBody`,
`authVerifyEmailResend`, `authVerifyEmailResent`, `authVerifyEmailBanner`.

**New route:** `/verify-email` (always accessible, no auth gate — the
user might be signed in but unverified).

**Edit/create guard:** in `create_listing_screen.dart` +
`development_form_screen.dart`, before submitting, check
`authState.value?.emailConfirmedAt`. If null, show the banner + push to
`/verify-email`. Don't gate the screens themselves — show a soft banner
at the top of the form so the user can browse and only gets blocked
on submit (matches web UX).

### 2. Dark mode real (🟡 D.3)

**State:** SharedPreferences-backed `ThemeMode` Riverpod notifier
(`themeModeProvider`). Defaults to `system`. Persists under
key `'app_theme_mode'`.

**MaterialApp:** add `darkTheme: AppTheme.darkTheme` (new) +
`themeMode: ref.watch(themeModeProvider)`.

**Theme file:** new `lib/core/theme/app_theme.dart` extracting the
existing `AppTheme.lightTheme` + adding `AppTheme.darkTheme` (color
swap: surface grey/black, primary unchanged, text/background adjusted).

**Settings tile:** replace `_comingSoon` SnackBar with a `CupertinoSegmentedControl<ThemeMode>` (or 3 ListTile radios) offering System / Light / Dark, calling `ref.read(themeModeProvider.notifier).set(mode)`.

### 3. Scaffold error-builder amigable (🟡 D.3)

In `lib/core/router/app_router.dart`'s top-level `errorBuilder`, replace
the raw `Text('Error: ${state.error}')` with a centered `ErrorView`
widget that shows a friendly icon + "Algo salió mal. Intenta de nuevo."
+ a `ElevatedButton` that does `router.go('/')`.

**New file:** `lib/core/widgets/error_view.dart` (small reusable widget —
also used by feature screens that need a fallback).

**New ARB keys:** `commonErrorFallback` (already exists as `commonErrorGeneric`),
`commonErrorFallbackRetry`.

### 4. Deeplink coverage (🟡 D.3)

Extend `lib/core/deeplink/deep_link_resolver.dart` to accept:
- `/promocionar/:listingId` (NOT `/payment/...` — that one already exists
  in Sprint 7 T4)
- `/perfil`
- `/mis-anuncios`
- `/favoritos`
- `/búsquedas-guardadas`

All require authentication in the web (the Flutter side already enforces
auth via the splash + protected routes — the deeplink just opens the
screen, and the screen handles unauth → redirect to `/login`).

No new screen widgets — these routes ALREADY exist in the Flutter router
(Sprints 1–4). The resolver just needs to accept them.

## Cross-cutting constraints

- No new dependencies.
- `flutter analyze` 0 errors after every task.
- `flutter test` — full suite (currently 105 tests) must stay green.
- Do NOT run `flutter build apk` inside tasks.
- The 3 uncommitted USER WIP files (firebase.json, firebase_options.dart,
  google-services.json) must NEVER be touched or staged.
- All UI strings via `l10n.*` — no hardcoded Spanish.

## Testing

- New widget tests:
  - `/verify-email` flow (resend button calls the service, success + error).
  - `themeModeProvider` defaults to `system` + persists.
  - Dark theme renders correctly (theme test).
  - `ErrorView` shows the icon + button.
  - `errorBuilder` route returns `ErrorView`, not raw text.
- Resolver tests: extend with 5 new paths (10 new test cases × 2 schemes).
- `auth_service_test.dart`: extend with email-verification methods
  (`resendVerificationEmail` happy + error).

## Phased plan

- **F1** — email-verification gate (authService resend method +
  /verify-email screen + banner in create/edit).
- **F2** — dark mode real (theme file + provider + MaterialApp wiring
  + Settings tile).
- **F3** — error-builder amigable + deeplink coverage (resolver +
  ErrorView + widget).
- **F4** — final verification + whole-branch review.

## Risks

- Email-verification resend can spam — debounce/throttle (60s).
- Dark theme may surface hardcoded white/black assumptions in widgets
  (audit: `AppColors.primary` etc. — most use primary which is theme-
  aware, but `Colors.white` literals might exist). Quick smoke pass.
- Deeplinks to authenticated routes open to anonymous users — must
  redirect to `/login` (screens already handle this — verify each).