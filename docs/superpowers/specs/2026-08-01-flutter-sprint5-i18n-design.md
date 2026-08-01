# Flutter Sprint 5 — i18n (es/en/it) + Static Pages (Design)

**Date:** 2026-08-01
**Status:** Approved (verbal)
**Scope:** Add full es/en/it localization to the Flutter app via the official
ARB + `flutter gen-l10n` tooling, then port the four static pages
(`/ayuda`, `/contacto`, `/privacidad`, `/terminos`) from the web. Builds on
Sprints 1–4 (the full marketplace + agency/B2B surface).

## Goal

Bring the Flutter app to i18n parity with `foxy_ads_web` for the curated 3-locale
overlay (es/en/it, with es as default), then port the four static pages
`/ayuda` (with FAQ search), `/contacto`, `/privacidad`, `/terminos` with
complete copy + UI matching the web.

## Architecture

ARB-based, the official Flutter i18n path:
- `lib/l10n/app_es.arb` / `app_en.arb` / `app_it.arb` — one per locale.
- `l10n.yaml` config at the project root:
  - `arb-dir: lib/l10n`
  - `template-arb-file: app_es.arb`
  - `output-localization-file: app_localizations.dart`
  - `nullable-getter: false`
- `flutter gen-l10n` → produces `AppLocalizations` (callable as
  `AppLocalizations.of(context)!.<key>` for type-safe access).
- Activation in `MaterialApp`:
  - `flutter_localizations` (already transitive; make explicit in pubspec).
  - `intl: ^0.20.2` (already present).
  - `localizationsDelegates: AppLocalizations.localizationsDelegates +
    [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate]`.
  - `supportedLocales: [Locale('es'), Locale('en'), Locale('it')]`.
- Persistence: `SharedPreferences` (already used in
  `selected_country_provider.dart`) with key `'app_locale'`. A `LocaleProvider`
  (Riverpod `NotifierProvider<LocaleNotifier, Locale>`) reads the key on init,
  writes on change. `MaterialApp.locale: ref.watch(localeProvider)`.

**Scope of locales: ONLY es/en/it.** The web has 138 locales (curated); Flutter
only ships the 3-locale overlay that matches the parity brief. If a device
requests a locale outside es/en/it, Flutter falls back to `supportedLocales.first`
= Spanish — matches the "untranslatable locales get Spanish" rule on the web
(their deep-merge in `request.ts` falls every other locale back to Spanish).

## ARB structure (mirrors the web's `messages/es.json` namespaces)

Every ARB has a top-level metadata block plus a flat key→string map. Keys use
lowercase_with_underscores. Parametric strings use ICU `{name}` placeholders.
Plurals use ICU plural categories.

Namespaces (in ARB, top-level keys for grouping):

- `app` — app name, tagline, global labels.
- `common` — universal UI: `save`, `cancel`, `yes`, `no`, `back`, `loading`,
  `errorGeneric`, `retry`, `close`, `search`, `continue`, `delete`, `edit`.
- `auth` — Login/Register screens: email, password, forgot-password, sign-in,
  sign-out, errors.
- `home` — Home screen: categories tiles, featured sections.
- `categoryDetail` — Listings within a category: titles, breadcrumb, sort.
- `listingDetail` — Listing detail: seller section, lead capture, report,
  favorite, share, view-count, coordinates.
- `listings` — List/my-listings: titles, filter chips, bulk actions.
- `publish` — Create/edit listing form: labels, hints, validation.
- `profile` — Profile screen: tiles, edit, settings entry points.
- `search` — Search bar + filters: placeholders, active filter chips.
- `savedSearches` — Saved searches: title, save, delete.
- `favorites` — Favorites screen: empty state, count.
- `header` / `footer` — Chrome.
- `localeSwitcher` — language picker label.
- `metadata` — page titles/descriptions.
- `help` — `/ayuda` page: pageTitlePrefix, pageTitleEmphasis, subtitle,
  searchPlaceholder, categoryAll, noResults, ctaHeading, ctaBody, ctaButton,
  `faqs` (an array, see below).
- `contact` — `/contacto`: pageTitle, intro, form labels (name/email/message),
  honeypot, infoSection, submitSuccess, submitError.
- `privacy` — `/privacidad`: pageTitle, sectionTitles (array), sectionBodies
  (array), lastUpdated.
- `terms` — `/terminos`: pageTitle, sectionTitles (array), sectionBodies
  (array), lastUpdated.
- `panel` — Pro Dashboard: tile labels (stats), section headings.
- `leads` — CRM leads inbox: filter, status labels, notes placeholder, errors.
- `agency` — Public agency profile + edit + verified badge.
- `developments` — Promociones (public + agency form).
- `valuation` — `/valorar`: page title, form labels, result card.
- `realEstate` — RE search filters.
- `notFound` — 404 page.

**ARB arrays** (e.g. `help.faqs`, `privacy.sectionBodies`):
- `help.faqs`: ICU list `[{ category, question, answer }, ...]` — the FAQs
  are category→questions; the UI groups by `category` and renders each as an
  `ExpansionTile`. Same shape as the web's `help.faqs`.
- `privacy.sectionBodies` / `terms.sectionBodies`: ICU lists of strings — the
  body of each section in order.
- `privacy.sectionTitles` / `terms.sectionTitles`: ICU lists of strings — the
  title of each section, parallel index to `sectionBodies`.

**Plurals** (`Intl.plural`):
- `listings.count`: `{count, plural, =0{Sin anuncios} one{1 anuncio} other{{count} anuncios}}`.
- `favorites.count`: same shape.
- `leads.count`: same shape.
- `search.results`: same shape.
- `savedSearches.count`: same shape.

## LocaleProvider

`lib/core/providers/locale_provider.dart`:
- `class LocaleNotifier extends Notifier<Locale>` — `build()` async-loads from
  SharedPreferences, defaults to `Locale('es')` when key missing or invalid.
  `setLocale(Locale)` persists + updates state.
- `final localeProvider = NotifierProvider<LocaleNotifier, Locale>(LocaleNotifier.new);`.
- The Notifier must throw in `build()` (it's an `AsyncNotifier`-style API) — but
  we want synchronous fallback to `Locale('es')` on load failure, so the cleanest
  approach is `Notifier<Locale>` with a `_load()` async helper, defaulting `state
  = Locale('es')` immediately and updating once SharedPreferences reads.
- Wire `MaterialApp.locale: ref.watch(localeProvider)`.

## LocaleSwitcher widget

`lib/core/widgets/locale_switcher.dart` — a popup `Menu` (3 entries: Español,
English, Italiano) with a leading globe icon. Tap a menu item → `ref.read(localeProvider.notifier).setLocale(Locale(...))`. Mounted in `profile_screen.dart`
(in the header, next to the country selector).

## Static pages

`lib/features/static/` (new module):
- `screens/help_screen.dart` (ConsumerStatefulWidget — holds the search
  query) → watches the FAQ list from `AppLocalizations.of(context).faqs`.
  - AppBar "Ayuda" (or "Help" in en). Subtitle. Search field with live
    filter: when the query is non-empty, only FAQs whose question OR answer
    contains the query (case-insensitive, accent-insensitive — normalize
    `String.toLowerCase().replaceAll(RegExp('[áéíóúñ]'), ...)` with a small
    map) are shown.
  - `ExpansionTile` per FAQ, grouped by `category`. Category chips at the top
    (an "Todas" + one per category); tapping filters by that category.
  - Empty state when the filter has no matches: `AppLocalizations.of(context).helpNoResults`.
  - CTA at the bottom: "Contactar soporte" → `context.push('/contacto')`.
- `screens/contact_screen.dart` (ConsumerStatefulWidget — holds form state).
  - AppBar "Contacto" / "Contact". Intro text. Form: name, email, message,
    hidden honeypot. Validate (reuse `LeadsService.validate` style — name
    1..120, email 3..200 + @, message 1..2000).
  - The form's submit does NOT call any backend (this sprint); on valid
    submit, show "Mensaje enviado. Te responderemos a {email}." SnackBar
    and reset the form. A `launchUrl` mailto on the support email
    `soporte@foxyads.com` is also offered as a fallback link.
  - Info section: support email, social media links (all `launchUrl`
    externalApplication).
- `screens/privacy_screen.dart` (ConsumerWidget) — AppBar
  "Política de privacidad" / "Privacy policy". A scrollable column of
  section titles + bodies (use `ListView.builder`).
- `screens/terms_screen.dart` (ConsumerWidget) — same pattern.

Routes:
- `/ayuda` → `HelpScreen`
- `/contacto` → `ContactScreen`
- `/privacidad` → `PrivacyScreen`
- `/terminos` → `TermsScreen`

Entry points:
- `profile_screen.dart` footer: add 4 `ListTile`s for the static pages
  (icon + text + onTap → `context.push(...)`).
- The `create_listing_screen.dart` footer (Sprint 1, the create flow) — add
  a small `Wrap` of "Política de privacidad" + "Términos de uso" text links
  → `context.push(...)`.

## Migration of hardcoded strings (~600 sites)

Three waves, each a Sprint task that lands as one or more commits with
`flutter test` green:

- **Wave 1 (F3)**: `auth`, `home`, `categoryDetail`, `listingDetail`,
  `listings`, `search`, `savedSearches` — about 12 screens.
- **Wave 2 (F4)**: `publish`, `profile`, `favorites`, `panel`, `leads`,
  `agency`, `developments`, `valuation`, `realEstate`, `notFound`,
  `common`, `header`, `footer`, `localeSwitcher`, `metadata`, `app` —
  all the Sprint 1–4 screens + chrome.
- **Wave 3 (F5)**: smoke pass — grep for any remaining Spanish hardcoded
  strings in lib/, fix any that surfaced; ensure `flutter analyze` 0
  errors and 65/65 tests still green after the ARB codegen runs.

Strings with parameters (e.g. `${n} viviendas`):
```arb
"developmentUnitCount": "{count, plural, =0{Sin viviendas} one{1 vivienda} other{{count} viviendas}}"
```
Use `AppLocalizations.of(context)!.developmentUnitCount(count)`.

Strings with non-ICU substitutions (e.g. `'Hola ' + name`):
```arb
"helloUser": "Hola {name}"
```
Use `AppLocalizations.of(context)!.helloUser(name)`.

Strings inside `const Text('literal')` widgets CANNOT use the locale directly
(the const constructor requires a const value). Migrate to
`Text(AppLocalizations.of(context)!.label)` (non-const constructor; this is
fine for `Text`).

## Testing

- `test/l10n_smoke_test.dart` — loads `AppLocalizations.delegate.load(Locale('es'))`
  and asserts a few spot-check keys exist (e.g. `common.save == 'Guardar'`,
  `app.name == 'Foxy Ads'`); same for `Locale('en')` and `Locale('it')`.
  Asserts every key present in `app_es.arb` is also present in
  `app_en.arb` and `app_it.arb` (parity check — `flutter gen-l10n` will
  fail the build otherwise).
- `test/help_search_test.dart` — a pure helper test: the FAQ filter
  function (case-insensitive, accent-insensitive match on
  question+answer) returns expected subsets for a few inputs.
- `test/locale_provider_test.dart` — `LocaleNotifier` with an in-memory
  `SharedPreferences.setMockInitialValues({})` defaults to `Locale('es')`;
  `setLocale(Locale('en'))` updates state and persists (rebuild → `Locale('en')`).
- Manual per phase: `flutter analyze` 0 errors, `flutter test` green, the
  app opens in the right locale after `LocaleSwitcher` flips it.

## Phased plan (one spec, plan in phases, sequential SDD)

- **F1** — i18n setup: `l10n.yaml`, ARB skeletons (`app_es.arb`/`app_en.arb`/`app_it.arb`)
  with `app`/`common`/`localeSwitcher`/`metadata` keys, `flutter gen-l10n`,
  `MaterialApp` wires delegates + supportedLocales, `LocaleProvider` +
  SharedPreferences persistence, smoke test.
- **F2** — `LocaleSwitcher` widget + mount in `profile_screen.dart`.
- **F3** — ARB migration wave 1: `auth`, `home`, `categoryDetail`, `listingDetail`,
  `listings`, `search`, `savedSearches` namespaces + 12 screens. ~200 string
  substitutions.
- **F4** — ARB migration wave 2: `publish`, `profile`, `favorites`, `panel`,
  `leads`, `agency`, `developments`, `valuation`, `realEstate`, `notFound`,
  `common`/`header`/`footer` chrome. ~300 string substitutions.
- **F5** — ARB migration wave 3: smoke pass — grep for residual Spanish
  hardcoded strings + final parity test.
- **F6** — Static pages: `/ayuda` (with FAQ search), `/contacto`,
  `/privacidad`, `/terminos` + routes + `AppRoutes` entries + entry points
  (profile footer + create-listing footer).
- **F7** — Verification + final whole-branch review.

## Out of scope

- The 138 locales from the web. Only es/en/it in Flutter.
- Backend for the `/contacto` form (no `submit_contact_lead` RPC; we
  show a fallback mailto).
- Localized dates/numbers beyond what each screen already does.
- Translating backend-driven dynamic strings (categories, cities, countries)
  — those come pre-localized from the backend.

## Risks

- **~600 string substitutions is mechanical but huge.** Mitigation: 3 waves,
  each a checkpoint; each wave's commit MUST have `flutter test` green.
- **`flutter gen-l10n` adds ~5–10s to first build after ARB changes.**
  Mitigation: run it explicitly between waves; outputs are gitignored.
- **Plurals** (count-dependent strings) need ICU `Intl.plural` — easy
  to forget. Mitigation: a parity test counts occurrences of
  `'plural,'` in each ARB and asserts they match.
- **Const widgets holding strings**: `const Text('literal')` blocks the
  i18n swap. Mitigation: drop the `const` (Text's constructor accepts a
  non-const String fine) — a smoke test at the end greps for
  `const Text('` and flags any survivors.