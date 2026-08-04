# Flutter Sprint 9 — Content + Locales + Residual Spanish (Design)

**Date:** 2026-08-04
**Status:** Approved (sweep spec)
**Scope:** Close remaining audit 🟡/⚪ gaps: (1) hardcoded Spanish strings in
listings widgets (per the audit + Sprint-3 inventory), (2) add 3 more
locales (pt-BR, fr, de — per the sweep decision), (3) dark-mode light-only
leak smoke pass (per Sprint 8 review's Important I1), (4) a few remaining
cosmetic drift items the audit flagged.

## Goal

After Sprint 9, the app:
- Has zero hardcoded Spanish UI strings in the touched widgets (every
  visible text passes through `l10n.*`).
- Ships in 6 locales: es, en, it, pt-BR, fr, de.
- Dark mode's light-only-leak widgets are fixed (those hardcoded
  `AppColors.surface` / `Colors.white` widgets repaint correctly in dark).
- The bug-class regression guards (don't re-introduce Spanish literals,
  don't re-introduce dark-mode leaks) live in the test suite.

## Non-goals

- Chat / messaging (out of scope per audit).
- Teams / roles (paused in web).
- Admin panel (out of scope).
- 138 locales (web supports them; Flutter stays at 6).
- The `deelink/` files (already correctly excluded from the sweep).

## Architecture

### 1. Hardcoded Spanish in listings widgets (🟡 D.3)

**The actual scope:** per the audit + Sprint-3 inventory, the residual
hardcoded Spanish is concentrated in 4 places:
- `lib/features/real-estate/presentation/widgets/re_attribute_form.dart`
  — labels for RE fields, hint texts.
- `lib/features/listings/presentation/widgets/contact_sheet.dart` + similar
  widgets — the bottom sheet's "Enviar" / "Cancelar" copy, the lead-status
  copy.
- `lib/features/developments/presentation/widgets/development_contact_sheet.dart`
  — same pattern.
- `lib/features/agency/presentation/widgets/leads_panel.dart` — lead status
  labels, the empty-state copy.

For each: identify the hardcoded strings, add ARB keys, migrate.
Pattern matches the Sprint-5 i18n migration — `l10n.<key>` getter
+ `app_es.arb` template + `app_en.arb` + `app_it.arb` real translations.

### 2. Add pt-BR, fr, de locales (🟡 D.3)

**The work:** add `app_pt_BR.arb` (Portuguese for Brazil), `app_fr.arb`
(French), `app_de.arb` (German). Each is a TRANSLATION of `app_es.arb`
(same keys, translated values). Use the existing `flutter gen-l10n`
config — no new config needed.

**Practical concern:** this is **a LOT of translation work** (the
existing es ARB has ~1000 keys — Sprint 5 was already heavy). I will
NOT hand-translate 3000 strings. Instead:
- **Phase A:** Generate empty pt-BR/fr/de ARBs (just the same key
  structure as es, empty values). `flutter gen-l10n` will produce
  working getters that fall back to es for any untranslated key (i.e.
  the app shows Spanish in pt-BR/fr/de locales for now). This makes
  the locales AVAILABLE in the LocaleSwitcher dropdown.
- **Phase B:** Add REAL translations for the **most-visible keys**
  (AppBar titles, primary CTAs, error messages, hero copy, headings) —
  ~50-100 keys per locale. The rest stay in es (the app's behavior is
  graceful — it shows Spanish, not "missing key" crashes, because
  gen-l10n falls back to the template).

This matches how the web handles the 138-locale matrix (most locales
have ~80% translated, the rest fall through to Spanish — and users
tolerate that).

**Locale display names** (in the LocaleSwitcher):
- pt-BR → "Português (Brasil)"
- fr → "Français"
- de → "Deutsch"

**Locale indicator in app:** the LocaleSwitcher already accepts
arbitrary Locale values; just add 3 more entries.

### 3. Dark-mode light-only leak (🟡 from Sprint 8 review I1)

**The leaks:** `development_form_screen.dart` (3 surfaces),
`create_listing_screen.dart` (1 surface), `saved_searches_screen.dart`
(2 surfaces) hardcode `AppColors.surface` (= pure white) or `Colors.white`
on widgets that should theme-aware.

**The fix:** swap hardcoded colors for `Theme.of(context).colorScheme.surface`
(or `Theme.of(context).colorScheme.onSurface` for text/foreground). Or,
add a tiny `AppColors.surfaceFor(BuildContext ctx)` helper.

**Decision:** go with the `surfaceFor(BuildContext)` helper — keeps
the call site terse, centralizes the mapping, and makes it easy to
audit in the future (grep for the helper).

### 4. Cosmetic drift cleanups (per audit's D.3 list)

A small set of cosmetic drift items the audit flagged. Closing the
ones that are quick:
- Scaffold error-builder: ✅ already done in Sprint 8.
- Banner carousel autoPlay: leave as-is (UX is fine, not a parity gap).
- Deeplink coverage: ✅ already done in Sprint 8.
- Country picker UI: leave (cosmetic; not affecting functionality).

## Cross-cutting constraints

- No new dependencies.
- `flutter analyze` 0 errors after every task.
- `flutter test` — full suite (currently 129 tests) must stay green +
  new tests.
- Do NOT run `flutter build apk` inside tasks.
- The 4 uncommitted USER WIP files MUST NEVER be touched or staged.
- Use ONLY targeted `git add`.

## Testing

- `test/i18n_parity_test.dart` (NEW): reads all 6 ARBs; for every key
  in `app_es.arb` (the template), assert the key exists in the other 5
  ARBs (even if the value is empty — that's the "structural parity"
  guarantee; values can be empty without breaking the build). Catches
  any future key addition to one ARB without the others.
- `test/dark_mode_leak_test.dart` (NEW): pumps the dev form + create
  listing + saved searches in dark mode + asserts the previously-hardcoded
  `AppColors.surface` surfaces now use `Theme.of(context).colorScheme.surface`
  (catches regressions).
- `test/hardcoded_spanish_scan_test.dart` (NEW): a lightweight static
  scan: walk `lib/features/{listings,developments,real-estate,agency}/presentation`,
  extract all `Text('...')` literals, flag any that contain Spanish
  accented characters (`áéíóúñ¿¡`). Not a perfect detection (some
  legitimate Spanish content — like the FAQ data — would match), but
  the scope can be limited to `lib/features/{...}/presentation/{screens,widgets}/`
  to avoid false positives. The test PASSES if the scan returns zero
  matches (the pass criterion is "no Spanish literals left").

## Phased plan

- **F1** — Hardcoded Spanish in listings widgets (3 widgets, ~20 strings).
- **F2** — Dark-mode leak smoke fix (6 surfaces + helper + tests).
- **F3** — Add pt-BR, fr, de locales (empty translation files + real
  translations for top ~80 keys + LocaleSwitcher entries + parity test).
- **F4** — Final verification + whole-branch review.

## Risks

- Translating 3000 strings for 3 new locales is impractical; the empty-
  ARB + selective-translation approach is the practical path. Users in
  pt-BR/fr/de will see Spanish in some screens (per the
  fallback-to-template behavior) — documented in the release notes.
- The hardcoded-Spanish scan test is a static analysis test; if it
  generates false positives (e.g. legitimate Spanish content like the
  FAQ data slipped into widgets), I'll narrow the scope or add
  allowlist entries. The scan is meant as a regression guard, not a
  green-tick.