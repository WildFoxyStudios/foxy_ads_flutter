# Flutter Sprint 7 — Payments (Stripe Checkout redirect) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire real Stripe payments into Flutter's promote-listing flow so
`/promote/:listingId` actually charges the user via Stripe Checkout (matches
the web's redirect flow 1:1). Add the `/payment/success` + `/payment/cancelled`
return-target routes. The bug `🔴 #1` from the audit is closed.

**Architecture:** Stripe Checkout Session (server-side), redirected to from
Flutter via `url_launcher` `externalApplication`. After Stripe processes
the payment, it redirects back to a deep-link URL (`foxyads://payment/success?session_id=…`)
that our deep-link resolver already accepts (extend it to also accept
`/payment/cancelled`). On success, a new `PaymentSuccessScreen` calls a
NEW Supabase edge function `/payments/resolve-session` (mirrors web's
`/api/payments/session-listing/[sessionId]/`) which verifies ownership and
returns the listingId + title. Flutter then navigates to `/listing/:id`
or `/mis-anuncios`. On cancelled, a `PaymentCancelledScreen` offers
"Try again" + "Volver al inicio". The webhook on the server-side
(`src/app/api/webhooks/stripe/route.ts`) is UNCHANGED — it does the actual
listing feature update on payment success. Flutter's job is just: kick off
the Checkout Session, handle the deep-link return, and show feedback.

**Tech Stack:** Flutter 3.44 / Dart 3.12, flutter_riverpod ^3, go_router ^17,
supabase_flutter ^2, url_launcher ^6, app_links ^6 (already wired).
NO new dependencies (the existing `pay:` plugin is REMOVED from
pubspec — we don't use it; Stripe Checkout is browser-based, no SDK).

## Global Constraints

- **Mirror the web 1:1:** every contract detail (Checkout Session shape,
  metadata keys, success/cancel URLs, edge function behavior) matches
  `foxy_ads_web/src/app/api/payments/create-checkout/route.ts` and the
  webhook handler. Don't invent a different schema.
- **Stripe keys:** the BACKEND needs `STRIPE_SECRET_KEY` +
  `STRIPE_WEBHOOK_SECRET` + `NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY` already
  (web has them). The Flutter app needs only `NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY`
  IF we ever show a Stripe element — but for Checkout redirect we DON'T
  need any Stripe key in Flutter. Nothing changes in Flutter's `.env`.
- **Real-money constraint:** the user will need a TEST Stripe account
  before running the Sprint 7 tasks; warn them. Use TEST mode keys
  (`pk_test_…` / `sk_test_…`) on the server. The Flutter app will only
  need to do `url_launcher(url)` — no Stripe SDK calls.
- **The 3 USER WIP files (firebase.json, firebase_options.dart,
  google-services.json) must NEVER be touched/staged/committed** —
  targeted `git add` only.
- **No new dependencies.** The unused `pay:` plugin is REMOVED from
  pubspec (it's dead — Sprint 7 explicitly confirms we use Checkout
  redirect).
- `flutter analyze` 0 errors + `flutter test` green after every task.
- Do NOT run `flutter build apk` (controller runs it at end).
- All UI strings via `l10n.*` — no hardcoded Spanish.

## File Structure

**Create**
- `lib/features/payments/data/payments_service.dart` — `PaymentsService`:
  `createCheckout({listingId, days}) -> Future<({String url, String sessionId})>`.
  Mirrors the web endpoint: POSTs to a new Supabase edge function
  `payments-create-checkout` (see Sprint 7 backend tasks below) with the
  caller's Supabase session token in the Authorization header.
- `lib/features/payments/data/payments_providers.dart` — providers.
- `lib/features/payments/presentation/screens/payment_success_screen.dart`.
- `lib/features/payments/presentation/screens/payment_cancelled_screen.dart`.
- `lib/features/payments/data/payments_service_test.dart` + `test/` updates.
- Backend (`foxy_ads_web/supabase/functions/payments-create-checkout/`):
  NEW Supabase edge function — mirrors the web's
  `src/app/api/payments/create-checkout/route.ts` semantics but as an
  Edge Function (so the Flutter client can invoke it directly).
- Backend (`foxy_ads_web/supabase/functions/payments-resolve-session/`):
  NEW edge function — mirrors the web's
  `src/app/api/payments/session-listing/[sessionId]/route.ts` semantics.
  (The existing Next.js webhook handler at
  `src/app/api/webhooks/stripe/route.ts` is UNTOUCHED — it still fires
  when Stripe redirects back to the web, OR when the user pays via
  Flutter and Stripe POSTs the webhook to the web. The webhook does
  the actual `applyFeature()` — the Flutter edge function only
  resolves the session-id to a listing-id for the success page UI.)

**Modify**
- `pubspec.yaml` — REMOVE `pay:` (unused; Stripe Checkout is redirect-
  based, no SDK). Also remove the dead `firebase_core` import in
  `lib/main.dart` ONLY IF it doesn't break anything; otherwise leave.
  (Don't touch firebase_options.dart or google-services.json — user WIP.)
- `lib/core/router/app_router.dart` — add routes:
  `/payment/success`, `/payment/cancelled`, AND `AppRoutes.paymentSuccess`,
  `AppRoutes.paymentCancelled`. Wire them in.
- `lib/core/deeplink/deep_link_resolver.dart` — accept
  `foxyads://payment/success?session_id=...` and
  `foxyads://payment/cancelled` (return
  `/payment/success?session_id=...` and `/payment/cancelled` respectively).
  Also accept `https://foxyads.app/payment/success?...` (web → app deep
  link for the web-pay-from-Flutter flow).
- `lib/features/payments/presentation/screens/promote_listing_screen.dart`
  — REWRITE the `_processPayment` flow: instead of calling
  `promoteListing` directly, call `paymentsService.createCheckout({listingId, days})`
  to get the Stripe Checkout URL, then `launchUrl(Uri.parse(url), mode:
  LaunchMode.externalApplication)` to open Stripe's hosted checkout in the
  browser. Preserve the existing tier grid + i18n copy + summary card.
  Remove the bogus `assert(method == 'card' || method == 'google_pay')`.
  Replace with "Continue to Stripe Checkout" button on each tier tile.
- `lib/l10n/app_{es,en,it}.arb` — new keys for the new screens + the
  promote-screen rewrite (Spanish translations only — en/it are
  reviewer-verified translations, NOT machine-translated).

**Routes + AppRoutes constants (additions to `app_router.dart`):**
- `static const paymentSuccess = '/payment/success';`
- `static const paymentCancelled = '/payment/cancelled';`
- Register both GoRoutes AFTER the static-pages routes; their dynamic
  param is `session_id` (success) or no param (cancelled). Register
  the static (no-param) cancelled route BEFORE any hypothetical
  dynamic catch-all under `/payment/...` — there's none, but
  consistent ordering (specific before generic).

---

## Backend prerequisites (need before Task 1)

These live in the `foxy_ads_web/` repo. The user (or I, in a separate session) needs to add:
1. `supabase/functions/payments-create-checkout/index.ts` — mirrors
   `src/app/api/payments/create-checkout/route.ts`. Uses the same
   `STRIPE_SECRET_KEY`, `FEATURE_PRICES`, `isValidFeatureDays`,
   `getFeaturePrice`, and inserts a `pending` row in `payments`. Returns
   `{ url, sessionId }` JSON. Requires the caller to send the Supabase
   user JWT in the Authorization header (Supabase Functions auto-attach
   the caller via the `user` context — verify via `supabase.auth.getUser(token)`).
2. `supabase/functions/payments-resolve-session/index.ts` — mirrors
   `src/app/api/payments/session-listing/[sessionId]/route.ts`. Takes
   `sessionId` as a query param, verifies session via Stripe, checks
   ownership, returns `{ listingId, title }` or an error code.

These are NOT in scope for this plan (they live in the web repo and the
web team owns them). The plan assumes they exist and are deployed. If
they don't, Tasks 1–4 of this plan will compile + test green, but Task 5
(the actual Stripe launch) will fail at runtime until the edges ship.

---

## Interfaces produced in T1, consumed throughout

```dart
// payments_service.dart
class PaymentsService {
  final SupabaseClient _supabase;
  PaymentsService(this._supabase);
  Future<({String url, String sessionId})> createCheckout({
    required String listingId,
    required int days,
  });
  Future<({String? listingId, String? title})> resolveSession(String sessionId);
  /// Stripe always charges €; this remains for consistency.
}
final paymentsServiceProvider = Provider<PaymentsService>(
    (ref) => PaymentsService(ref.watch(supabaseClientProvider)));
```

Deep-link additions:
```
foxyads://payment/success?session_id=cs_test_X   → /payment/success?session_id=cs_test_X
foxyads://payment/cancelled                     → /payment/cancelled
https://foxyads.app/payment/success?session_id=X → /payment/success?session_id=X
https://foxyads.app/payment/cancelled           → /payment/cancelled
```

---

## Task 1: Backend edge-function contract + Flutter service skeleton

**Files:**
- Create: `lib/features/payments/data/payments_service.dart`,
  `lib/features/payments/data/payments_providers.dart`,
  `test/payments_service_test.dart`
- Modify: `lib/l10n/app_es.arb` (add `paymentsContinueToCheckout`,
  `paymentSuccessPageTitle`, `paymentSuccessLoading`, `paymentSuccessReady`,
  `paymentSuccessPending`, `paymentSuccessError`,
  `paymentSuccessMissingSession`, `paymentSuccessGoToListing`,
  `paymentSuccessGoToMyListings`, `paymentCancelledPageTitle`,
  `paymentCancelledBody`, `paymentCancelledRetry`, `paymentCancelledBack`,
  `paymentCancelledHelpPrefix`, `paymentCancelledHelpLink`,
  `paymentCheckoutError`, `paymentCheckoutCancel`)

**Interfaces produced:** `PaymentsService` + provider + ARB keys.

- [ ] **Step 1: Write the failing service tests** (`test/payments_service_test.dart`):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:foxy_ads/core/services/_test_fakes.dart'; // or inline a fake
import 'package:foxy_ads/features/payments/data/payments_service.dart';

void main() {
  test('createCheckout POSTs to /functions/v1/payments-create-checkout '
       'with listingId+days and returns (url, sessionId)', () async {
    final fake = FakeSupabaseClient(...)
    final svc = PaymentsService(fake);
    final r = await svc.createCheckout(listingId: 'list-1', days: 7);
    expect(r.url, 'https://checkout.stripe.com/c/pay/cs_test_…');
    expect(r.sessionId, 'cs_test_…');
  });

  test('createCheckout throws on non-200', () async {
    final svc = PaymentsService(fake(returns 500));
    expect(() => svc.createCheckout(listingId: 'x', days: 7), throwsException);
  });

  test('resolveSession returns (listingId, title) for a valid paid session',
        () async { ... });
  test('resolveSession returns (null, null) when Stripe says not paid', ...);
}
```

Use the existing fake-Supabase pattern (`promote_listing_screen_test.dart`
or any other test that mocks Supabase — read `test/_fakes.dart` or
inline `class FakeSupabaseClient extends SupabaseClient` if there isn't
a shared fake file).

- [ ] **Step 2: Run — expect FAIL.**

- [ ] **Step 3: Implement `PaymentsService`** (mirror the web endpoint):

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/providers/supabase_provider.dart';

class PaymentsService {
  PaymentsService(this._supabase);
  final SupabaseClient _supabase;

  Future<({String url, String sessionId})> createCheckout({
    required String listingId,
    required int days,
  }) async {
    final res = await _supabase.functions.invoke(
      'payments-create-checkout',
      body: {'listingId': listingId, 'days': days},
    );
    final data = res.data is Map ? res.data as Map : <String, dynamic>{};
    if (res.status != 200 || data['url'] is! String || data['sessionId'] is! String) {
      throw Exception('Checkout creation failed: ${res.status}');
    }
    return (url: data['url'] as String, sessionId: data['sessionId'] as String);
  }

  Future<({String? listingId, String? title})> resolveSession(String sessionId) async {
    final res = await _supabase.functions.invoke(
      'payments-resolve-session',
      queryParameters: {'sessionId': sessionId},
    );
    if (res.status != 200) return (listingId: null, title: null);
    final data = res.data is Map ? res.data as Map : <String, dynamic>{};
    return (
      listingId: data['listingId'] as String?,
      title: data['title'] as String?,
    );
  }
}

final paymentsServiceProvider = Provider<PaymentsService>(
    (ref) => PaymentsService(ref.watch(supabaseClientProvider)));
```

Note: `supabase.functions.invoke` automatically attaches the caller's
session JWT — the edge function's `createClient(supabaseUrl, anonKey, {global: {headers: {Authorization: ...}}})` pattern reads it from the headers. Verify by reading how the web's other edge functions (`delete-account`, etc.) are invoked.

- [ ] **Step 4: Add the ARB keys** (Spanish template; en/it added later by Task 6):

```json
"paymentsContinueToCheckout": "Continuar a Stripe",
"paymentsCheckoutError": "No se pudo iniciar el pago. Inténtalo de nuevo.",
"paymentsCheckoutCancel": "Pago cancelado. No se ha cobrado nada.",
"paymentSuccessPageTitle": "Pago realizado",
"paymentSuccessLoading": "Verificando tu pago...",
"paymentSuccessReady": "¡Listo! Tu anuncio está destacado.",
"paymentSuccessPending": "Tu pago está en proceso. Te avisaremos en unos minutos.",
"paymentSuccessError": "No pudimos verificar el pago.",
"paymentSuccessMissingSession": "Falta el identificador de sesión.",
"paymentSuccessGoToListing": "Ver anuncio",
"paymentSuccessGoToMyListings": "Volver a mis anuncios",
"paymentCancelledPageTitle": "Pago cancelado",
"paymentCancelledBody": "No se ha realizado ningún cargo. Puedes intentarlo de nuevo cuando quieras.",
"paymentCancelledRetry": "Reintentar",
"paymentCancelledBack": "Volver al inicio",
"paymentCancelledHelpPrefix": "¿Necesitas ayuda?",
"paymentCancelledHelpLink": "Contactar soporte"
```

Run `flutter gen-l10n`.

- [ ] **Step 5: Run tests — PASS. `flutter analyze` (0 errors). Commit.**

```bash
git add -A && git commit -m "feat(payments): service skeleton + ARB keys"
```

---

## Task 2: Rewrite `_processPayment` to launch Stripe Checkout

**Files:**
- Modify: `lib/features/payments/presentation/screens/promote_listing_screen.dart`

**Interfaces produced:** the screen now calls `paymentsService.createCheckout`
and `launchUrl(url)` instead of `promoteListing`.

- [ ] **Step 1: Replace `_processPayment` body.** The current code (per Sprint-7
  audit) is:
  ```
  _processPayment(method) {
    assert(method == 'card' || method == 'google_pay');
    listingService.promoteListing(...);
  }
  ```
  Replace the entire flow:
  ```
  Future<void> _processPayment() async {
    final svc = ref.read(paymentsServiceProvider);
    try {
      final r = await svc.createCheckout(
        listingId: widget.listingId,
        days: _selectedDays,
      );
      // Preserve the sessionId in a SharedPreferences-bound field so the
      // deep-link return can correlate (only if you implement a "resume
      // payment" flow — out of scope here). For now, just launch.
      await launchUrl(
        Uri.parse(r.url),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      // Show a SnackBar with l10n.paymentsCheckoutError; don't pop the screen.
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.paymentsCheckoutError)));
    }
  }
  ```
  Remove the `method` parameter from `_processPayment` and from each tile's
  `onPressed`. Remove the `_PaymentMethod` enum / class (Card/Google Pay
  tiles collapse into a single "Continuar a Stripe" CTA per tier).
  KEEP the tier grid UI, the summary card, the i18n copy. Add ONE primary
  CTA per tier tile that reads `l10n.paymentsContinueToCheckout`.

- [ ] **Step 2: Drop the `pay:` package** from pubspec — it's unused.
  Verify `flutter pub get` resolves cleanly (some transitive dep might
  pull it; if so, leave it and note the warning).

- [ ] **Step 3: Update any existing widget test** for `promote_listing_screen`
  that asserted the old behavior (e.g. "doesn't take money, just promotes").
  Update the test to expect the new flow: tapping a tier triggers
  `paymentsService.createCheckout` and `launchUrl`. Mock both. The test
  suite must stay green.

- [ ] **Step 4: `flutter analyze` (0 errors) + `flutter test` (green). Commit.**

```bash
git add -A && git commit -m "feat(payments): promote_screen launches Stripe Checkout (redirect)"
```

---

## Task 3: Payment success + cancelled screens

**Files:**
- Create: `lib/features/payments/presentation/screens/payment_success_screen.dart`,
  `lib/features/payments/presentation/screens/payment_cancelled_screen.dart`
- Modify: `lib/core/router/app_router.dart` (add routes + AppRoutes constants)

- [ ] **Step 1: Implement `PaymentSuccessScreen`** (ConsumerStatefulWidget):
  - Reads `session_id` from `state.uri.queryParameters['session_id']`.
  - On `initState`, calls `paymentsService.resolveSession(sessionId)`.
  - State: loading → ready (has listingId+title) → pending (resolveSession
    returned nulls — webhook hasn't landed yet) → error (network/500).
  - Renders one of 4 corresponding UI states using the new ARB keys:
    `paymentSuccessLoading` (spinner), `paymentSuccessReady` (✓ icon +
    title + `paymentSuccessGoToListing` button → `/listing/:id`),
    `paymentSuccessPending` (clock icon + retry/refresh button),
    `paymentSuccessError` (⚠ icon + "Mis anuncios" button).
  - `missingSessionError` case: if no session_id in the URL, show error
    state with "Mis anuncios" CTA.
  - Mirrors `src/app/[locale]/pago-exitoso/page.tsx` exactly.

- [ ] **Step 2: Implement `PaymentCancelledScreen`** (ConsumerWidget):
  - Renders a centred "Pago cancelado" card (× icon + title + body).
  - Two buttons: `paymentCancelledRetry` → `/promote/:listingId` if a
    query param `listing_id` is present (deep-link may carry it), else
    `/mis-anuncios`. `paymentCancelledBack` → `/`.
  - Help text: "paymentCancelledHelpPrefix" + "/contacto" link.
  - Mirrors `src/app/[locale]/pago-cancelado/page.tsx` exactly.

- [ ] **Step 3: Wire routes + AppRoutes** in `app_router.dart`:

```dart
static const paymentSuccess = '/payment/success';
static const paymentCancelled = '/payment/cancelled';
// in the route list, after the static-pages routes:
GoRoute(path: AppRoutes.paymentSuccess, builder: (c, s) {
  final sessionId = s.uri.queryParameters['session_id'];
  return PaymentSuccessScreen(sessionId: sessionId);
}),
GoRoute(path: AppRoutes.paymentCancelled, builder: (c, s) {
  final listingId = s.uri.queryParameters['listing_id'];
  return PaymentCancelledScreen(listingId: listingId);
}),
```

- [ ] **Step 4: `flutter analyze` (0 errors) + `flutter test` (green). Commit.**

```bash
git add -A && git commit -m "feat(payments): payment_success + payment_cancelled screens"
```

---

## Task 4: Deep-link resolver extension + return-to-app flow

**Files:**
- Modify: `lib/core/deeplink/deep_link_resolver.dart`
- Modify: `lib/l10n/app_es.arb` (no new keys)

**Interfaces produced:** `foxyads://payment/success?session_id=X` →
`/payment/success?session_id=X`; `foxyads://payment/cancelled` →
`/payment/cancelled`; the https equivalents.

- [ ] **Step 1: Extend the resolver** to accept:
  - `foxyads://payment/success?session_id=…` → `/payment/success?session_id=…`
  - `foxyads://payment/cancelled?listing_id=…` → `/payment/cancelled?listing_id=…`
  - `https://foxyads.app/payment/success?session_id=…` → same
  - `https://foxyads.app/payment/cancelled?listing_id=…` → same

  Note: the resolver's return type is `String?` (a go_router location) but
  the router `go()` method doesn't accept query strings via a typed
  signature — `Uri.parse` with query works. The CURRENT resolver returns
  paths like `/anuncio/123` without query strings. For these new payment
  cases, the resolver MUST return paths that include `?session_id=…` —
  add a new return type or a new shape. Decide:
  - (a) Return a `Uri` (parseable path + query) instead of a `String`.
    Update `resolveDeepLink`'s return type; update `_navigate` in
    `deep_link_service.dart` to pass the `Uri` to `router.go`.
  - (b) Return the path AND a query-string separately (refactor signature).
  - (c) Hack: return `/payment/success%3Fsession_id=…` with an encoded
    `?` so go_router sees the path part (rejected — go_router would URL-
    decode and pass through to the wrong screen).
  - Pick (a). It's a small refactor. Update the resolver's return type
    to `Uri?` (and its tests). Update `_navigate` to `router.go(uri)`.

- [ ] **Step 2: Update the resolver tests** (`test/deep_link_resolver_test.dart`)
  to use the `Uri?` return type and add the 4 new payment cases.

- [ ] **Step 3: Update `deep_link_service.dart`** to pass the `Uri` to
  `router.go(...)`. (Should be a 1-line change.)

- [ ] **Step 4: Configure `AndroidManifest.xml` + iOS Info.plist** if
  needed — they should already accept any path on the foxyads.app hosts
  (per Sprint 6 fix). But Stripe's redirect URLs are
  `https://checkout.stripe.com/...` — those are EXTERNAL, not our domain.
  The user pays IN THE BROWSER; the browser redirects back to
  `https://foxyads.app/payment/success?session_id=…` (or
  `foxyads://payment/success?session_id=…` if Stripe is configured with
  the universal link). For the redirect to open the app on mobile,
  configure Stripe's `success_url` to use the `foxyads://` scheme (NOT
  `https://`). The web's current `success_url` is `${origin}/pago-exitoso?…`
  — the Flutter backend equivalent should use `foxyads://payment/success?…`.
  NOTE in your report: the user must configure Stripe Checkout's
  `success_url` + `cancel_url` accordingly (this happens server-side in
  the edge function — not a Flutter change, but a Flutter-side
  consequence: the deep-link resolver must accept the foxyads:// scheme
  for payment paths, which this task does).

- [ ] **Step 5: `flutter analyze` (0 errors) + `flutter test` (green —
  including the resolver tests with the 4 new cases). Commit.**

```bash
git add -A && git commit -m "feat(deeplink): accept payment return paths"
```

---

## Task 5: Stripe-side wiring notes + smoke test scaffold

**Files:**
- Create: `docs/PAYMENT_TESTING.md` (a SHORT note for the user)

**Interfaces produced:** the user has a checklist for testing Stripe end-to-end.

- [ ] **Step 1: Write `docs/PAYMENT_TESTING.md`**:
  - Required env vars on the BACKEND (Stripe dashboard):
    `STRIPE_SECRET_KEY=sk_test_…`, `STRIPE_WEBHOOK_SECRET=whsec_…`,
    `NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=pk_test_…`.
  - The edge function `payments-create-checkout` MUST return a
    `success_url` of the form
    `foxyads://payment/success?session_id={CHECKOUT_SESSION_ID}`
    (NOT `https://foxyads.app/...` — Android users need the app to
    re-open after Stripe completes the redirect). Add this to the
    edge function as a follow-up; if the user wants to keep the
    https success_url for the web, they can pass a `platform` query
    param from Flutter so the server chooses the right one.
  - How to test end-to-end (the user):
    1. Apply test data: install Flutter app on Android emulator.
    2. Sign in as a verified test user (your own account).
    3. Create a test listing → tap "Promocionar".
    4. Pick a tier → tap "Continuar a Stripe".
    5. Browser opens to Stripe Checkout; use test card `4242 4242 4242 4242`.
    6. After Stripe approves, browser redirects to `foxyads://payment/success?session_id=…`.
    7. App reopens at /payment/success → loads listing → CTA "Ver anuncio".
    8. Verify the listing is now featured (webhook landed; `promote_listing`
       equivalent applied the UPDATE).

- [ ] **Step 2: Run all tests + `flutter analyze`** (must be 0 errors /
  all green). Commit.

```bash
git add -A && git commit -m "docs(payments): end-to-end testing checklist for Stripe"
```

---

## Task 6: en/it translations for the new ARB keys

**Files:**
- Modify: `lib/l10n/app_en.arb`, `app_it.arb`

- [ ] **Step 1: Add the 18 new keys from Task 1 to both en and it** with
  REAL translations (not Spanish-as-English/Italian). The en strings:
  - `paymentsContinueToCheckout`: "Continue to Stripe"
  - `paymentsCheckoutError`: "Could not start the payment. Please try again."
  - `paymentsCheckoutCancel`: "Payment cancelled. You were not charged."
  - `paymentSuccessPageTitle`: "Payment successful"
  - `paymentSuccessLoading`: "Verifying your payment..."
  - `paymentSuccessReady`: "Done! Your listing is now featured."
  - `paymentSuccessPending`: "Your payment is processing. We'll let you know in a few minutes."
  - `paymentSuccessError`: "We couldn't verify the payment."
  - `paymentSuccessMissingSession`: "Missing session identifier."
  - `paymentSuccessGoToListing`: "View listing"
  - `paymentSuccessGoToMyListings`: "Back to my listings"
  - `paymentCancelledPageTitle`: "Payment cancelled"
  - `paymentCancelledBody`: "You have not been charged. Feel free to try again whenever."
  - `paymentCancelledRetry`: "Try again"
  - `paymentCancelledBack`: "Back to home"
  - `paymentCancelledHelpPrefix`: "Need help?"
  - `paymentCancelledHelpLink`: "Contact support"

  Italian translations are real Italian (the implementer must produce them
  — the previous sprints established this is the standard).

- [ ] **Step 2: Run `flutter gen-l10n` + `flutter analyze` + `flutter test`**
  (must be 0 errors / green). Commit.

```bash
git add -A && git commit -m "feat(i18n): en/it translations for payment screens"
```

---

## Task 7: Whole-branch review

- [ ] **Step 1:** `flutter analyze` + `flutter test` + `flutter build apk
  --debug` (controller runs the build).
- [ ] **Step 2:** Generate the review package (`scripts/review-package
  MERGE_BASE HEAD` — MERGE_BASE = the commit Sprint 7 started from,
  i.e. the head of the sweep-spec commit).
- [ ] **Step 3:** Dispatch ONE final code reviewer (most capable model).
  Reviewer checks: every code path is real-money-safe (no `promoteListing`
  bypasses payment); the resolver's `Uri?` refactor doesn't break Sprint-6
  links; the screen tests cover both checkout-success and checkout-cancel;
  no `pay:` import left; the deep-link return opens the app correctly on
  Android (Stripe redirect → foxyads:// → deep-link → success screen).
  Triage findings, dispatch ONE fix subagent if Critical/Important.
- [ ] **Step 4:** If clean, record Sprint 7 in the progress ledger.

---

## Self-Review (author)

- **Spec coverage:** the audit's D.1.1 (promote_listing bug) is closed by
  Tasks 1–2; D.2.2 (payment routes) is closed by Task 3; the
  return-to-app deep-link path is closed by Task 4; the testing
  checklist is Task 5; the en/it ARB is Task 6; the review is Task 7. ✓
- **Type consistency:** the resolver's `String?` → `Uri?` refactor is a
  breaking change for `_navigate` — handled atomically in Task 4 with
  tests.
- **No placeholders** beyond the unavoidable ones: the backend edge
  functions live in `foxy_ads_web/` (out of repo scope), but the Flutter
  service code treats them as already-deployed contracts. The user's
  Stripe keys are external.
- **Security:** the success screen does NOT trust the URL — it asks the
  server (`resolveSession`) which verifies ownership. A guessed
  `session_id` returns null → "pending" or "error" state. Matches the
  web's defense-in-depth pattern (per the audit's `paymentsSessionListing`
  docstring).