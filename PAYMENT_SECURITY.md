# Payment Security — Self-Service Wallet Top-Up (eSewa)

This document records the security controls built into the driver wallet
top-up feature. The feature lets a driver load money into their wallet through
an online payment provider (eSewa sandbox for now) with **no admin in the
loop**. Because it moves real money, it is designed to production security
standards from the start.

## Trust model (the one rule)

> The client can never assert that a payment happened. It can only ask the
> backend to **re-verify** with the provider. Money is credited **only** after
> a server-to-server confirmation from eSewa.

Everything below follows from that rule.

## End-to-end flow

```
App  ──POST /wallet/payments/esewa/initiate {amount}──▶  Backend
                                                          • validates amount
                                                          • creates WalletTopup (status=initiated)
                                                          • HMAC-signs the eSewa form
App  ◀──────────── {paymentId, gatewayUrl, signed fields} ──────────
App  ──auto-POST signed form (in-app WebView)──▶  eSewa gateway (HTTPS)
                                                  • user authenticates & pays
eSewa ──redirect success_url──▶  WebView (intercepted; NOT trusted)
App  ──POST /wallet/payments/esewa/verify {paymentId}──▶  Backend
                                                          • GET eSewa status API (server-to-server, HTTPS)
                                                          • require status == COMPLETE
                                                          • require amount matches signed amount
                                                          • atomic, once-only wallet credit
App  ◀──────────── {status: completed, balance} ──────────
```

## Controls

### 1. Payment verification is server-side only
`PaymentsService.verifyEsewa` calls eSewa's transaction-status API
(`EsewaService.queryStatus`) server-to-server over HTTPS and credits the wallet
**only** when eSewa reports `COMPLETE`. The browser/WebView success redirect is
treated purely as a UI signal to trigger verification — it never credits money.
(`esewa.service.ts`, `payments.service.ts`)

### 2. Data-tampering protection (HMAC signatures)
- The outbound eSewa form is signed with HMAC-SHA256 over
  `total_amount,transaction_uuid,product_code`, so a driver cannot alter the
  amount in the WebView without invalidating the signature.
- On verify, we additionally assert the amount eSewa reports equals the amount
  we signed. A mismatch is refused **and** recorded as a fraud event
  (`topup_amount_mismatch`, score 40).
- The provider's success `data` blob can be signature-checked with
  `verifyCallbackSignature` (constant-time compare) as defence in depth.

### 3. Wallet balances cannot be manipulated from the client
There is no client-writable balance field and no self-credit endpoint. The
only path that increases a balance is `creditOnce`, reached exclusively after a
verified `COMPLETE` status. The removed legacy "instant top-up request" and all
admin approval endpoints are gone.

### 4. Duplicate payments / replay / double-credit prevention
- `WalletTopup.transactionUuid` is **unique** — one intent, one credit.
- `WalletTopup.providerRef` (eSewa's ref) is **unique** — a provider reference
  can be credited at most once.
- `creditOnce` runs inside a DB transaction and flips the status with a
  **conditional `UPDATE ... WHERE status IN ('initiated','pending')`**. Only the
  caller that wins the transition (`count === 1`) performs the credit;
  concurrent/duplicate verifies read the already-completed row and credit
  nothing. Idempotent by construction.
- Intents older than `ESEWA_INTENT_TTL_MINUTES` (default 30) are expired and
  can never be credited (stale-callback / replay window closed).

### 5. AuthN / AuthZ on every endpoint (no IDOR)
- All `/wallet/payments/*` routes are behind `JwtAuthGuard`.
- The acting user is taken from the JWT (`@CurrentUser`), **never** from the
  request body. `verifyEsewa` loads the intent and rejects it with `404` unless
  `topup.userId === caller.id`, so a user can only ever touch their own intents.

### 6. Rate limiting / abuse protection
- Global `ThrottlerGuard` (100 req/min) plus tighter per-route limits:
  initiate 10/min, verify 20/min.
- Max 20 top-up intents per user per 24h; exceeding it records a fraud event
  (`topup_intent_spam`) and blocks.
- One live (`initiated`/`pending`) intent per user at a time — a retap reuses
  the existing intent instead of leaking orphans.
- Amount bounds enforced server-side (`ESEWA_MIN_TOPUP`..`ESEWA_MAX_TOPUP`) in
  addition to DTO validation.

### 7. Input validation
- `InitiateTopUpDto`: `amount` must be an integer within bounds (`class-validator`,
  global `ValidationPipe`).
- `VerifyTopUpDto`: `paymentId` must be a UUID.
- eSewa form values are HTML-attribute-escaped before being placed in the
  auto-submit form (`esewa_payment_webview.dart`). Prisma (parameterized
  queries) removes SQL-injection surface.

### 8. Encryption in transit
- eSewa gateway + status endpoints are HTTPS.
- The mobile app enforces HTTPS in release builds and supports certificate
  pinning (`DioClient`). Status queries use a 15s timeout with `AbortController`
  so a hung provider can't stall wallet operations.

### 9. Secrets management
- The eSewa signing secret and all endpoints come from environment variables
  (`ESEWA_SECRET_KEY`, `ESEWA_*_URL`, `ESEWA_PRODUCT_CODE`). **Nothing is
  hardcoded in source.**
- Production **fails to boot** without `ESEWA_SECRET_KEY` (fail-secure). Dev
  falls back only to eSewa's *public sandbox* key for local testing.
- `.env` is git-ignored; `.env.example` documents the variables with sandbox
  placeholders only.

### 10. No sensitive payment data stored
The app never sees or stores card/eSewa credentials — the user authenticates
inside eSewa's own page. We persist only non-secret references (our UUID,
eSewa's ref, amount, status, timestamps, and the initiating IP for audit).

### 11. Full audit trail
- `WalletTopup` rows record the entire lifecycle (initiated → completed/failed/
  expired) with timestamps, provider ref, and the linked wallet-transaction id.
- `AuditService` logs `topup.initiated` and `topup.credited`.
- Every credit creates an immutable `WalletTransaction` (`source: 'topup'`).
- Anomalies (amount mismatch, intent spam) are written to `FraudEvent`.

## Environment variables

| Variable | Purpose | Prod requirement |
|---|---|---|
| `ESEWA_SECRET_KEY` | HMAC signing secret | **Required (boot fails without it)** |
| `ESEWA_GATEWAY_URL` | ePay-v2 form endpoint | Set to live endpoint |
| `ESEWA_STATUS_URL` | Transaction status endpoint | Set to live endpoint |
| `ESEWA_PRODUCT_CODE` | Merchant/service code | Live merchant code |
| `ESEWA_SUCCESS_URL` / `ESEWA_FAILURE_URL` | WebView redirect targets (not trusted for crediting) | Your https URLs |
| `ESEWA_INTENT_TTL_MINUTES` | Intent expiry window | default 30 |
| `ESEWA_MIN_TOPUP` / `ESEWA_MAX_TOPUP` | Per-transaction amount bounds | tune to policy |

## Going to production (checklist)

- [ ] Replace sandbox `ESEWA_SECRET_KEY` / `ESEWA_PRODUCT_CODE` with live
      merchant credentials (delivered by eSewa after successful test txns).
- [ ] Point `ESEWA_GATEWAY_URL` / `ESEWA_STATUS_URL` at the live endpoints.
- [ ] Set `ESEWA_SUCCESS_URL` / `ESEWA_FAILURE_URL` to real app-owned https URLs.
- [ ] Keep `NODE_ENV=production` so secret + HTTPS fail-secure checks are active.
- [ ] Enable certificate pinning (`CERT_PINS`) in the mobile build.
- [ ] Confirm a background job expires stale intents (or rely on lazy expiry in
      `verifyEsewa`).
