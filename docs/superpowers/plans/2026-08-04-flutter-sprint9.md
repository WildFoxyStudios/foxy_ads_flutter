# Flutter Sprint 9 — Content + Locales + Residual Spanish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close audit gaps 🟡 D.3 (hardcoded Spanish in listings widgets),
expand locales to 6 (es/en/it + pt-BR/fr/de), and fix the dark-mode
light-only-leak that the Sprint-8 review flagged as Important I1.

**Architecture:** Migrate ~20 hardcoded Spanish strings in 3-4 widgets to
ARB keys. Add 3 new locale ARBs (pt-BR, fr, de) — translation files for
the existing key structure; only ~80 visible keys get REAL translations,
the rest fall back to es via the gen-l10n template behavior. Fix 6
hardcoded `AppColors.surface` / `Colors.white` surfaces to use a
`surfaceFor(BuildContext)` helper.

**Tech Stack:** Flutter 3.44 / Dart 3.12, flutter_riverpod ^3, go_router ^17.

## Global Constraints

- No new dependencies.
- All UI strings via `l10n.*` — no hardcoded Spanish.
- `flutter analyze` 0 errors after every task.
- `flutter test` — full suite green after every task (currently 129).
- Do NOT run `flutter build apk`.
- The 4 uncommitted USER WIP files MUST NEVER be touched or staged.
- Use ONLY targeted `git add` — NEVER `git add -A`.

## File Structure

**Create**
- `lib/core/theme/theme_colors.dart` — `surfaceFor(BuildContext) ->
  Color` helper.
- `lib/l10n/app_pt_BR.arb`, `app_fr.arb`, `app_de.arb` — translation
  files (mostly empty for fallback, real translations for the top ~80
  visible keys).
- `test/i18n_parity_test.dart` — every key in es exists in all 6 ARBs.
- `test/dark_mode_leak_test.dart` — light-only-leak surfaces now theme-
  aware.
- `test/hardcoded_spanish_scan_test.dart` — static scan for Spanish
  literals in the 4 feature directories (lists, developments, RE, agency).

**Modify**
- `lib/features/real-estate/presentation/widgets/re_attribute_form.dart` —
  migrate the ~10 hardcoded Spanish labels/hints.
- `lib/features/listings/presentation/widgets/contact_sheet.dart` — migrate
  the "Enviar", "Cancelar", lead status copy, etc.
- `lib/features/developments/presentation/widgets/development_contact_sheet.dart`
  — same.
- `lib/features/agency/presentation/widgets/leads_panel.dart` — lead status
  labels + empty-state copy.
- `lib/features/developments/presentation/screens/development_form_screen.dart`
  — 3 hardcoded `AppColors.surface`/`Colors.white` → `surfaceFor(ctx)`.
- `lib/features/listings/presentation/screens/create_listing_screen.dart` —
  1 hardcoded surface → `surfaceFor(ctx)`.
- `lib/features/search/presentation/screens/saved_searches_screen.dart` —
  2 hardcoded surfaces → `surfaceFor(ctx)`.
- `lib/l10n/app_es.arb` — add the new keys (template, per F1).
- `lib/l10n/app_en.arb` + `app_it.arb` — add the new keys (per F1).
- `lib/core/widgets/locale_switcher.dart` — add 3 more Locale entries
  (pt-BR, fr, de).
- `lib/l10n/locale_provider.dart` — extend `supported` to 6 locales.

---

## Task 1: Hardcoded Spanish in listings widgets

**Files:** 4 widget files + 3 ARB files + 1 test.

- [ ] **Step 1: Inventory.** Read each of the 4 widgets and list every
  hardcoded Spanish string. Write to
  `.superpowers/sdd/sprint9-t1-inventory.md` (one screen/section per
  heading; each string as a bullet with proposed ARB key).

- [ ] **Step 2: Add the keys to `app_es.arb`** (Spanish template; en/it
  + the 3 new locales follow in F3). Use the exact Spanish from the
  inventory. Run `flutter gen-l10n`. Confirm getters present.

- [ ] **Step 3: Migrate the widgets.** Replace each hardcoded string with
  `AppLocalizations.of(context)!.<key>`. Drop `const` on wrapping widgets
  where needed. Add the l10n import.

- [ ] **Step 4: Add the same keys to `app_en.arb` and `app_it.arb`** with
  real translations. Run `flutter gen-l10n`.

- [ ] **Step 5: Add `test/hardcoded_spanish_scan_test.dart`.** Walk
  `lib/features/{listings,developments,real-estate,agency}/presentation/`,
  extract all `Text('...')` literals (regex: `'([^'\\]|\\.)*'`), flag any
  containing Spanish accented characters (`áéíóúñ¿¡`) or
  Spanish-only words. The test PASSES if the scan returns zero matches.
  Add an explicit allowlist comment for known legitimate Spanish
  (e.g. the FAQ data — but that's a different file, not a widget).

- [ ] **Step 6: `flutter analyze` (0 errors) + `flutter test` green. Commit.**

```bash
git add <only the files you changed>
git commit -m "fix(i18n): migrate residual hardcoded Spanish in listings widgets"
```

## Task 2: Dark-mode light-only-leak fix

**Files:** 3 widget files + 1 helper + 1 test.

- [ ] **Step 1: Create `lib/core/theme/theme_colors.dart`:**

```dart
import 'package:flutter/material.dart';

/// Theme-aware surface color. Use in place of `AppColors.surface` /
/// `Colors.white` for widget surfaces that should repaint correctly in
/// both light and dark modes. Background widgets that NEED a white surface
/// (e.g. image placeholder) should continue to use `AppColors.surface` directly.
Color surfaceFor(BuildContext context) =>
    Theme.of(context).colorScheme.surface;
```

- [ ] **Step 2: Swap hardcoded surfaces in the 3 widgets.** Read each
  file; find the `AppColors.surface` / `Colors.white` references; replace
  with `surfaceFor(context)`. Import the helper. Total ~6 swaps.

- [ ] **Step 3: Add `test/dark_mode_leak_test.dart`.** Pump each of the
  3 widgets in a `MaterialApp` with `themeMode: ThemeMode.dark`; pump
  again with `ThemeMode.light`. For the dark pump, assert the surfaces
  are NOT `Colors.white` / `0xFFFFFFFF` (use `Theme.of(context).colorScheme.surface`
  as the expected color). The test catches regressions.

- [ ] **Step 4: `flutter analyze` (0 errors) + `flutter test` green. Commit.**

```bash
git add <only the files you changed>
git commit -m "fix(theme): replace hardcoded light surfaces with theme-aware surfaceFor"
```

## Task 3: Add pt-BR, fr, de locales

**Files:** 3 new ARBs + 1 provider edit + 1 widget edit + 1 test.

- [ ] **Step 1: Create the 3 new ARBs as TRANSLATIONS of `app_es.arb`.**
  For each locale (pt-BR, fr, de):
  - Copy the entire `app_es.arb` structure.
  - For the **top ~80 visible keys** (app bar titles, primary CTAs, error
    messages, hero copy, headings — sample a subset of:
    `appName`, `commonSave`/`Cancel`/`Retry`/`Continue`/`Delete`/`Edit`,
    `auth*`, `home*`, `search*`, `profile*`, `settings*`, `help*`, `contact*`,
    `privacy*`, `terms*`, `payment*`, `verify*` etc.):
    - Add REAL translations.
  - For all OTHER keys: leave the value as the es text (or empty string)
    — the gen-l10n template fallback handles missing-value gracefully
    by falling back to es.
  - Add `"@@locale": "pt_BR"` (or `"fr"`, `"de"`) at the top.

- [ ] **Step 2: Extend `lib/l10n/locale_provider.dart`** `supported` list:

```dart
static const supported = [
  Locale('es'),
  Locale('en'),
  Locale('it'),
  Locale('pt', 'BR'),
  Locale('fr'),
  Locale('de'),
];
```

  And in `_loadFromPrefs` / `setLocale`, match by `languageCode` (so
  `pt_BR` and `pt` both resolve to `pt_BR`).

- [ ] **Step 3: Extend `lib/core/widgets/locale_switcher.dart`** with 3
  more `_options` entries:
  - `('🇧🇷', Locale('pt','BR'), 'Português (Brasil)')`
  - `('🇫🇷', Locale('fr'), 'Français')`
  - `('🇩🇪', Locale('de'), 'Deutsch')`
  Update the type signature if needed (`_options` becomes a record or
  class with 3 fields).

- [ ] **Step 4: Add `test/i18n_parity_test.dart`.** Read all 6 ARBs as
  JSON; assert that for every key in `app_es.arb`, the same key exists
  in `app_en.arb` / `app_it.arb` / `app_pt_BR.arb` / `app_fr.arb` /
  `app_de.arb` (structural parity — even if the value is empty, the key
  must be there). This is the regression guard.

- [ ] **Step 5: `flutter analyze` (0 errors) + `flutter test` green. Commit.**

```bash
git add <only the files you changed>
git commit -m "feat(i18n): add pt-BR, fr, de locales + LocaleSwitcher entries"
```

## Task 4: Whole-branch review + signed release APK

- [ ] **Step 1:** `flutter analyze` + `flutter test` (must be 0 errors /
  green). `flutter build apk --release --no-pub` (controller runs).
- [ ] **Step 2:** Generate the review package
  (`scripts/review-package MERGE_BASE HEAD` — MERGE_BASE = sprint-9 spec
  commit, `f6f7d28`).
- [ ] **Step 3:** Dispatch ONE final code reviewer (most capable model)
  with the package + this plan's attention lens. Triage findings,
  dispatch ONE fix subagent if Critical/Important.
- [ ] **Step 4:** If clean, record Sprint 9 in the progress ledger +
  update the memory file.

---

## Self-Review (author)

- **Spec coverage:** hardcoded Spanish in 4 widgets (F1), dark-mode leak
  in 3 widgets (F2), 3 new locales (F3), whole-branch review (F4). ✓
- **Type consistency:** the `surfaceFor(context)` helper is a thin
  wrapper over `Theme.of(context).colorScheme.surface`; existing
  `AppColors.surface` continues to work for widgets that genuinely need
  a white surface (e.g. image placeholders that shouldn't theme-shift).
- **No placeholders** beyond the unavoidable: the Spanish-static-scan
  test is the closest thing to a "placeholder" — it's a best-effort static
  check, not perfect.
- **Risk:** the pt-BR/fr/de translations for the top 80 keys require
  real human-quality translation; the implementer should produce them,
  not hand-wave. en/it Spanish-as-translation was a Sprint-5 lesson.