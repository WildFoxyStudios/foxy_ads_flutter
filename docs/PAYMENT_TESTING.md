# Stripe payments — end-to-end testing checklist

The Flutter app is wired for Stripe Checkout (T1–T4 of this sprint built
the redirect flow, the success/cancelled screens, and the deep-link return
path). The two Supabase edge functions that the Flutter app calls
(`PaymentsService` in `lib/features/payments/data/payments_service.dart`)
have **not** been authored yet — they live in the sibling repo
`foxy_ads_web/supabase/functions/`. This is a one-page checklist for you
to stand those up and smoke-test the whole flow on an Android emulator.

---

## 1. Backend env vars (Supabase project — edge function runtime)

Set these on the Supabase project's edge function env
(`supabase secrets set …` for the local CLI, or the Supabase dashboard
Edge Functions → Secrets):

| Variable | Value |
| --- | --- |
| `STRIPE_SECRET_KEY` | `sk_test_…` (use the test-mode key from the Stripe dashboard) |
| `STRIPE_WEBHOOK_SECRET` | `whsec_…` (from the Stripe webhook endpoint's signing secret) |
| `NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY` | `pk_test_…` (publishable key, exposed to the browser — the edge function doesn't need it but the web Next.js app does, so keep the naming consistent with the web) |

Canonical wiring already exists in the web project for reference:

- `foxy_ads_web/src/lib/stripe/config.ts` — reads the three vars above.
- `foxy_ads_web/src/app/api/webhooks/stripe/route.ts` — verifies the
  webhook signature and runs the `applyFeature()` UPDATE that flips the
  listing to featured. The edge function mirror of this endpoint just
  needs to forward the same event handling — the Supabase webhook
  endpoint must point at the same Stripe webhook URL so the existing
  handler keeps working for both web and Flutter.

---

## 2. Edge functions to add (in `foxy_ads_web/supabase/functions/`)

Two new edge functions, names match what `PaymentsService.invoke('<name>', …)` calls:

### `payments-create-checkout`

Mirror of `src/app/api/payments/create-checkout/route.ts`. Contract:

- **Request body** (JSON): `{ listingId: string, days: number }`.
- **Auth**: the caller's Supabase JWT (sent by `supabase.functions.invoke`
  automatically) — verify it, then look up the listing in `listings` to
  confirm the caller owns it.
- **Response** (200): `{ url: string, sessionId: string }`.
- **Calls** Stripe's `checkout.sessions.create({...})` with
  `mode: 'payment'`, the tier's amount, the listing id in metadata, and
  the `success_url` / `cancel_url` described below.

### `payments-resolve-session`

Mirror of `src/app/api/payments/session-listing/[sessionId]/route.ts`.
Contract:

- **Request query**: `?sessionId=<stripe_session_id>`.
- **Auth**: caller's Supabase JWT.
- **Response** (200): `{ listingId: string, title: string }` — read
  `metadata.listingId` and pull `title` from the `listings` row.
- Non-2xx responses (e.g. session not yet completed) are swallowed by the
  client and rendered as a "pending" state — that's fine, don't crash.

---

## 3. CRITICAL — `success_url` must use the `foxyads://` scheme

The web's current `success_url` is `${origin}/pago-exitoso?session_id={CHECKOUT_SESSION_ID}`,
which works for the browser. **For Flutter, the deep-link return path
needs the custom scheme** so Android reopens the app instead of dropping
the user on a 404 page:

```
foxyads://payment/success?session_id={CHECKOUT_SESSION_ID}
```

Stripe's `{CHECKOUT_SESSION_ID}` placeholder gets substituted with the
actual session id, then the resolver in
`lib/core/deeplink/deep_link_resolver.dart` (Sprint 7 Task 4) routes
`foxyads://payment/success?session_id=…` to `/payment/success`,
preserving the query string. The success screen reads `session_id`,
calls `PaymentsService.resolveSession`, and lands on the listing.

**Recommended approach** so both web and Flutter keep working without
branching on the URL server-side:

- Read an optional `platform` query param from the request body
  (`platform: 'web' | 'flutter'`).
- If `platform === 'flutter'`, return
  `foxyads://payment/success?session_id={CHECKOUT_SESSION_ID}`.
- Otherwise, default to the existing `${origin}/pago-exitoso?session_id={CHECKOUT_SESSION_ID}`.
- Cancellation is symmetric: `foxyads://payment/cancelled?listing_id=…`
  for Flutter, the original `/pago-cancelado?listing_id=…` for web.

The Android manifest already accepts any `https://foxyads.app/*` (the
Sprint 6 fix) and the `foxyads://` scheme is registered (see
`deeplink/README.md`), so both forms reach the app intact.

---

## 4. Manual test plan (Android emulator, Stripe TEST card)

Test card: `4242 4242 4242 4242` — any future expiry, any CVC, any
ZIP. Run the app with the signed debug APK
(`flutter build apk --debug` or `flutter run`).

1. Install the app on an Android emulator (or `flutter run`).
2. Sign in as a verified test user (your own account).
3. Create a test listing → tap **Promocionar**.
4. Pick a tier → tap **Continuar a Stripe**.
5. The browser opens to Stripe Checkout — pay with `4242 4242 4242 4242`.
6. After Stripe approves, the browser redirects to
   `foxyads://payment/success?session_id=…`.
7. The app reopens at `/payment/success` → loads the listing → CTA
   **Ver anuncio** is visible.
8. Verify the listing is now featured (the webhook landed and
   `applyFeature()` ran the UPDATE — quick check: the listing appears
   at the top of the catalog with a "Destacado" badge).

If the listing is still unfeatured after a few seconds, the webhook
didn't fire — check the Stripe dashboard's webhook log and the
`stripe_webhook_events` table for the event id and delivery status.

---

## 5. Reference

- Deep-link config + Android manifest setup: `deeplink/README.md`.
- Deep-link resolver (return path routing):
  `lib/core/deeplink/deep_link_resolver.dart`.
- Stripe wiring on the web (canonical):
  `foxy_ads_web/src/lib/stripe/config.ts`,
  `foxy_ads_web/src/app/api/webhooks/stripe/route.ts`.
- Web checkout route to mirror:
  `foxy_ads_web/src/app/api/payments/create-checkout/route.ts`,
  `foxy_ads_web/src/app/api/payments/session-listing/[sessionId]/route.ts`.
- Client contract: `lib/features/payments/data/payments_service.dart`.
