# Flutter Parity Sweep — Multi-Sprint Design

**Date:** 2026-08-04
**Status:** Approved (verbal — "barrido completo, reparar todo")
**Scope:** Close every gap in `.superpowers/sdd/audit-foxy-ads-vs-web.md` to
bring the Flutter app to full functional parity with `foxy_ads_web` (admin
panel + Teams/roles + web-only routes remain OUT OF SCOPE per user direction).

**Decision log (2026-08-04):**
- Pagos: **Stripe real** (flutter_stripe + PaymentSheet) — paridad total iOS+Android.
- Email verification: **gate enforced** (banner + publish blocker).
- Locales extra: **pt-BR + fr + de** (4 más comunes después de es/en/it).
- Alcance: **TODO el reporte** (40 huecos: 1 🔴 bug + 3 🟠 features + ~10 🟡 drift + ~25 ⚪ cosméticos).

## Architecture

The sweep is broken into **5 sprints** (the report's section E suggestions,
slightly reordered so the bug blocker lands first and each sprint is
reviewable on its own). Each sprint gets its own plan and own SDD loop.

### Sprint 7 — Payments (foundational)
**Closes:** D.1.1 (🔴 promote_listing bug), D.2.2 (🟠 payment routes).
**Approach:** flutter_stripe ^4 + Stripe PaymentSheet (Card + Apple Pay +
Google Pay). Server side: new Supabase edge functions mirror the web's
`createCheckoutSession` + webhook flow; on success Flutter navigates to
`/payment/success`, on cancel to `/payment/cancelled`. Both routes show
appropriate user feedback. Card copy in UI matches the web's.

### Sprint 8 — Auth + UX polish + deeplink coverage
**Closes:** D.2.1 (🟠 email verification gate), D.3 dark mode, D.3
scaffold error-builder, D.3 deeplink coverage (add `/promocionar`, `/perfil`,
`/mis-anuncios`, `/favoritos`, `/búsquedas-guardadas` to the resolver).
**Approach:** SharedPreferences-backed `email_verified` banner + gate at
`/create-listing` and `/edit-listing/:id` if not verified; dark theme +
`ThemeMode` notifier persisted; friendly error screen in go_router
`errorBuilder`; deeplink resolver widened (no new routes, just new cases).

### Sprint 9 — Content + locales + residual Spanish
**Closes:** D.3 hardcoded Spanish strings in listings widgets, 🟡 locale
count drift.
**Approach:** Walk every widget touched by the Sprint-3 audit's residual
list; port strings. Add pt-BR, fr, de to all three ARBs (es template
already exists; pt-BR + fr + de get translated copies). Verify no
parity-test fails.

### Sprint 10 — Validation & QA
**Closes:** D.3 "agency verified gate QA" + "bulk select-all QA" + "lead
optimistic rollback QA", all widget-test gaps.
**Approach:** Add widget tests for each Pro Dashboard section's most
load-bearing behavior; integration test for category→detail→contact-sheet
→ lead submit (anon + authed paths); verify the foundation test suite
still passes 100%.

### Sprint 11 — Production gate (final)
**Closes:** Full pre-release audit. Release-signed APK (already
configured in Sprint 7). CHANGELOG/release notes documenting the gap
closure vs web. `flutter analyze` 0 errors, `flutter test` green, APK
builds signed, smoke-tested on the existing emulator path.

## Non-goals

- Admin panel (`/admin-foxy/*`) — web-only, per user direction.
- Teams/roles — paused even on web; not a Flutter gap.
- 138-locale web parity — Flutter ships 6 locales after this sweep.
- Sitemap/robots/OpenGraph image route — web-only.
- Stripe Customer Portal (receipts) — out of scope unless explicitly
  requested.

## Cross-cutting constraints (apply to every sprint)

- No new architectural changes; reuse the existing services/providers/router.
- Real Stripe sandbox keys are required for Sprint 7 (live publishable +
  secret); `flutter_stripe` needs the merchant ID + URL scheme
  configuration. The user will provide; flag this in Sprint 7's plan.
- All i18n strings flow through `l10n` — no hardcoded UI strings in any
  new screen/widget.
- `flutter analyze` 0 errors after every sprint. `flutter test` suite
  green. `flutter build apk --release` signed.
- The 3 uncommitted USER WIP files (firebase.json, firebase_options.dart,
  google-services.json) must NEVER be touched or staged.

## Test/verification

- Every sprint's spec acceptance criteria + the consolidated audit's
  gap-list as a final checklist.
- After Sprint 11: `flutter analyze` 0 errors, `flutter test` full
  green, signed release APK builds, smoke test against `flutter run`
  (manual — emulator on the existing CI/local path).

## Out of scope (this SPEC, not the sweep itself)

- Chat/messaging: web has no `/chat` route, so no Flutter gap.
- Web-only routes (sitemap, robots, OpenGraph image): out of scope.
- Teams/roles CRM: web is paused; not a Flutter gap.