# Flutter Sprint 10 — Missing Features (AI chat + AdMob + minor routes) Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or executing-plans.

**Goal:** Close the component-level parity gaps the census found: (1) the AI
"Foxy" chat assistant, (2) AdMob banners (mobile equivalent of the web's
AdSense), (3) the 2 minor routes (`/anuncios` browse-all-with-sort +
`/categoria/:slug/:subcategory`).

**Design decisions (approved by user 2026-08-04):**
- AI chat: call the web's ALREADY-DEPLOYED endpoint `https://foxyads.app/api/chat`
  directly (public POST, rate-limited by IP). Request `{messages:[{role,content}],
  temperature, maxTokens}` → response `{content}`. Backed by Groq
  `llama-3.1-8b-instant`. NO new backend needed.
- AdMob: use `google_mobile_ads` + Google's OFFICIAL TEST ad unit IDs (public,
  safe). Ship a hand-off doc for the user to swap in real IDs + AdMob app ID.
- Minor routes: `/anuncios` reuses the existing listings query with a sort
  dropdown; `/categoria/:slug/:subcategory` extends the existing category screen.

## Global Constraints

- `flutter analyze` 0 errors + `flutter test` green after every task.
- Do NOT run `flutter build apk` inside tasks.
- The USER WIP files must NEVER be touched/staged: `firebase.json`,
  `lib/firebase_options.dart`, `android/app/google-services.json`,
  `android/app/build.gradle.kts`, `android/app/src/main/AndroidManifest.xml`
  (user removed vercel host), and the DELETED `deeplink/*` (user moved to web).
  Use ONLY targeted `git add` — NEVER `git add -A`.
- All UI strings via `l10n.*`.

## Task 1: AI chat "Foxy" — service + provider + tests

**Files:** create `lib/features/chat/data/chat_service.dart` +
`chat_models.dart` + `chat_providers.dart` + `test/chat_service_test.dart`.

- `ChatMessage { String role; String content; }` (role: system/user/assistant).
- `ChatService`:
  - `Future<String> send(List<ChatMessage> messages, {double temperature = 0.7, int maxTokens = 200})`
    — HTTP POST to `https://foxyads.app/api/chat` with `{messages: [...], temperature, maxTokens}`;
    parse `{content}`; throw on non-200 (429 → a friendly "demasiadas
    peticiones" message). Use the `http` package (already a transitive dep;
    if not direct, add it — it's tiny). Confirm via pubspec.
  - A `_systemPrompt` constant: the Spanish "Foxy" persona (mirror the web's —
    grep `src/components/chat/AIChatBubble.tsx` for the system prompt string
    and port it verbatim as the seed message).
- `chatServiceProvider` (Provider).
- Tests: `send` happy path (mock the http client → returns `{content:'hola'}`),
  `send` throws on 429, `send` throws on 500. Use a mockable http client
  (inject `http.Client` into `ChatService`).

## Task 2: AI chat UI — floating bubble + chat sheet

**Files:** create `lib/features/chat/presentation/widgets/chat_bubble.dart` +
`chat_sheet.dart`; modify `lib/main.dart` (or the nav shell) to overlay the
bubble on every screen.

- `ChatBubble` — a `FloatingActionButton`-style draggable bubble (bottom-right)
  with the fox emoji 🦊. Tap → opens `ChatSheet` (a `showModalBottomSheet` or a
  full-height sheet). The web's bubble is draggable + persisted; for v1, a
  fixed bottom-right FAB is acceptable (note the drag as a follow-up).
- `ChatSheet` (ConsumerStatefulWidget) — message list (user bubbles right,
  assistant left) + a text input + send button + a typing indicator. On send:
  append the user message, call `chatService.send(history)`, append the
  assistant reply. Seed the history with the system prompt. Spanish error
  SnackBar on failure. Scroll-to-bottom on new message.
- Mount the bubble GLOBALLY: the cleanest is to wrap the `MaterialApp.router`'s
  `builder:` with a `Stack` that overlays `ChatBubble` above the routed content
  (so it appears on every screen). Verify this doesn't break the existing
  `builder` (locale/theme). If a global overlay is too invasive, mount the
  bubble only on the home + listing-detail + search screens (where the web shows
  it most). Prefer the global overlay if clean.
- ARB keys: `chatBubbleTooltip`, `chatSheetTitle`, `chatInputHint`,
  `chatSend`, `chatError`, `chatRateLimited`, `chatWelcome` (the assistant's
  opening line). Add to es/en/it (+ pt_BR/fr/de can fall back to es via the
  template — but add the ~7 keys to all 6 to satisfy the parity test).

## Task 3: AdMob banners

**Files:** modify `pubspec.yaml` (add `google_mobile_ads: ^5`), `lib/main.dart`
(init MobileAds), create `lib/features/ads/ad_banner.dart` + `ad_config.dart`;
create `docs/ADMOB_SETUP.md`.

- `ad_config.dart`: the Google OFFICIAL TEST ad unit IDs (banner:
  `ca-app-pub-3940256099942544/6300978111` Android, iOS test id too) + a
  `kUseTestAds` flag. A `// TODO(user): replace with real AdMob ad unit IDs`
  marker. The AdMob APP ID goes in `AndroidManifest.xml` `<meta-data
  android:name="com.google.android.gms.ads.APPLICATION_ID">` — BUT the manifest
  is a USER WIP file; do NOT edit it. Instead, document in `docs/ADMOB_SETUP.md`
  that the user must add the AdMob app-id meta-data to their manifest (with the
  test app id `ca-app-pub-3940256099942544~3347511713` for dev). Note this
  clearly — AdMob CRASHES on launch without the app-id meta-data, so the ads
  are GATED behind a flag that's OFF until the user adds the meta-data.
- `ad_banner.dart`: an `AdBanner` widget that loads + shows a banner ad. GATED
  behind `kAdsEnabled` (default FALSE until the user configures AdMob) so the
  app doesn't crash without the manifest meta-data. When disabled, renders
  `SizedBox.shrink()`.
- Mount `AdBanner` on the home screen (below the featured rail) + the listing
  detail (bottom) — mirror where the web shows AdSense.
- `MobileAds.instance.initialize()` in `main.dart` — but ONLY call it when
  `kAdsEnabled` (else it may throw without the app-id). Guard it.
- `docs/ADMOB_SETUP.md`: how to (1) create an AdMob account + app, (2) add the
  app-id meta-data to AndroidManifest + Info.plist, (3) replace the test ad unit
  IDs in `ad_config.dart`, (4) flip `kAdsEnabled` to true.

## Task 4: Minor routes

**Files:** modify `app_router.dart`; create/extend the browse-all screen +
subcategory handling.

- `/anuncios` (browse all listings with sort): add `AppRoutes.anuncios =
  '/anuncios'` + a screen that reuses `ListingService.getListings` with a sort
  dropdown (newest/oldest/price-low/price-high — mirror the web's `ListingSort`).
  Could reuse `category_listings_screen` with a null-category + sort, or a new
  `all_listings_screen.dart`. Add a nav entry (e.g. a "Ver todos los anuncios"
  tile in all-categories or home).
- `/categoria/:slug/:subcategory`: extend `category_listings_screen` to accept
  an optional subcategory param (the route `/category/:categoryId` already
  exists; add `/category/:categoryId/:subcategoryId`). Filter listings by
  subcategory. Verify the web's behavior (grep `categoria/[slug]/[subcategory]/page.tsx`).

## Task 5: Whole-branch review + signed release build

- `flutter analyze` + `flutter test` + `flutter build apk --release --no-pub`.
- Review package + final reviewer. Fix Critical/Important. Record + memory.

## Self-Review

- Coverage: AI chat (T1-T2), AdMob (T3), minor routes (T4), review (T5). ✓
- The chat calls the LIVE `foxyads.app/api/chat` — no backend work. The AdMob
  is test-ad-gated so it can't crash the app before the user configures it.
- Risk: the global chat-bubble overlay could conflict with the theme/locale
  builder in main.dart — T2 verifies. AdMob without the manifest app-id crashes
  — mitigated by the `kAdsEnabled=false` default gate.