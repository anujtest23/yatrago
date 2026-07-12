# YatraGo — System Architecture & Technical Reference

Version 1.0. Companion docs: [`DEPLOYMENT.md`](./DEPLOYMENT.md),
[`../PAYMENT_SECURITY.md`](../PAYMENT_SECURITY.md),
[`../SECRET_ROTATION_RUNBOOK.md`](../SECRET_ROTATION_RUNBOOK.md).

---

## 1. Overall system architecture

Three deployable units in one monorepo:

| Unit | Stack | Role |
|---|---|---|
| `yatrago-api` | NestJS + Prisma + PostgreSQL (PostGIS) + Redis | REST API, WebSocket chat, cron jobs, business logic |
| `yatrago-admin` | React + Vite + Tailwind | Admin console (SPA) binding `/admin/*` |
| `yatrago_app` | Flutter (Riverpod, GoRouter, Dio) | Passenger + driver mobile app |

```
┌─────────────┐     REST /api/v1      ┌──────────────────────────┐
│ yatrago_app │ ───────────────────▶ │        yatrago-api        │
│  (Flutter)  │  Socket.IO /chat     │  NestJS modules + guards  │
└─────────────┘ ───────────────────▶ │                          │
┌─────────────┐     REST /admin/*     │   Prisma ─▶ PostgreSQL    │
│yatrago-admin│ ───────────────────▶ │   RedisService ─▶ Redis   │
│   (React)   │                       │   Cron (@nestjs/schedule) │
└─────────────┘                       └───────────┬──────────────┘
                          eSewa gateway ◀──────────┘  (server-verify only)
```

- **Global prefix** `/api/v1`; Socket.IO gateway bypasses the prefix (namespace `/chat`).
- **Response envelope**: every REST response is `{ success, data, message }` (ResponseInterceptor).
- **Global guards/pipes**: ThrottlerGuard (rate limit), ValidationPipe (`whitelist:true`, `transform:true`), AllExceptionsFilter.
- Modules are feature-scoped under `src/modules/*`; cross-cutting services (audit, wallet, SMS, storage, fraud, config) live in a `@Global()` `PlatformModule`.

---

## 2. Database schema (PostgreSQL via Prisma)

Source of truth: `yatrago-api/prisma/schema.prisma`. Migrations in `prisma/migrations`.

**Core domains**
- **Identity & auth**: `User` (phone-unique; `role`, `activeMode`, `accountStatus`, `isActive`, TOTP fields, `fraudScore`, `notificationPreferences`/`privacySettings` JSON), `AuthSession` (hashed refresh tokens, family lineage, device/geo), `ReactivationRequest`.
- **Rides**: `DriverProfile`, `Vehicle` (+`VehicleDocument`), `Ride` (PostGIS lat/lng, seats, price, status), `Booking` (status, `paymentStatus`, `couponCode`, `discountAmount`), `Message` (chat, keyed by booking).
- **Money**: `Wallet`, `WalletTopup` (eSewa intents, idempotent credit, refund fields), `Payout`, `Commission`.
- **Coupons**: `Coupon`, `CouponRedemption` (`@@unique([bookingId])`, `applied|reversed`).
- **Support**: `SupportTicket` (Contact Us), `IssueReport` (Report Issue), `UserReport`, `Rating`.
- **Safety/ops**: `EmergencyContact` (`sortOrder`), `SosAlert`, `FraudEvent`, `AuditLog`, `Notification`, `DeviceToken`, `PlatformConfig`.

Key enums: `AccountStatus(active|pending_deletion|deleted)`, `ReactivationStatus`, `DiscountType`, `CouponAudience`, `RedemptionStatus`, `SupportStatus`, `IssueCategory`, `WalletTopupStatus`, `BookingStatus`, `RideStatus`.

All personal-data relations cascade on user delete where appropriate; deleted accounts are **retained** (not row-deleted) to support reactivation — see §7.

---

## 3. Backend API surface

Interactive reference: **Swagger at `/api/docs`** (enabled outside production, or via `SWAGGER_ENABLED`). Highlights by area:

- **Auth** `/auth`: `send-otp`, `verify-otp`, `refresh`, `logout`, `logout-all`, `me`, `sessions`, TOTP `totp/*`.
- **Users** `/users/me`: profile, mode switch, profile-photo, notification-settings, `notification-preferences`, `privacy-settings`, data `export`, deletion `deletion/{request-otp,confirm,cancel}`.
- **Rides/Bookings** `/trips`, `/bookings`, `/search`.
- **Chat** `/chat`: `conversations`, `unread-count`, `:bookingId/messages` (GET/POST), `:bookingId/read` + Socket.IO `/chat`.
- **Wallet/Payments** `/wallet`, `/wallet/payments/esewa/{initiate,verify,reconcile}`, `/wallet/topups`, `/drivers/payouts`.
- **Coupons** `/coupons/validate`.
- **Support** `/support/{tickets,issues,attachments}`.
- **Safety** `/users/me/emergency-contacts` (+ `/reorder`), `/sos`.
- **Admin** `/admin/*`: dashboard, users, drivers, vehicles, trips, bookings, payouts, sos, reports, coupons, `support/{tickets,issues}`, `reactivations`, config, audit-logs, fraud, admins.

Guards: `JwtAuthGuard` (all authenticated routes), `PendingDeletionGuard` (mutating routes), `AdminGuard`/`SuperAdminGuard`/`AdminIpGuard` (admin surface).

---

## 4. Authentication flow

Phone + OTP, JWT access + opaque rotating refresh tokens.

1. `POST /auth/send-otp` → CSPRNG 6-digit OTP, hashed (HMAC+pepper) in Redis (5-min TTL). Layered rate limits: per-IP (`otp_ip`), per-phone (`otp_sends`), plus route throttle.
2. `POST /auth/verify-otp` → timing-safe compare; on success issues a **15-min JWT access token** (issuer/audience pinned, RFC 8725) and an **opaque refresh token** whose SHA-256 is stored in `AuthSession` (raw token never persisted).
3. Refresh rotates the token within a `familyId`; reuse of a rotated token revokes the whole family (theft response, RFC 6819).
4. Admin accounts may enrol **TOTP MFA** — OTP alone never returns tokens for them; they must pass `totp/verify`.
5. `JwtStrategy.validate` re-loads the user each request and rejects `!isActive` (admin-suspended) and `accountStatus === 'deleted'`.

Anomaly signals (GeoIP country change, impossible travel, Tor exit, device farming) feed `fraudScore` without blocking login.

---

## 5. Wallet / payment flow (eSewa)

Full detail in [`PAYMENT_SECURITY.md`](../PAYMENT_SECURITY.md). Summary:

- **Server-verify-only trust model**: the client never computes signatures. `POST /esewa/initiate` creates a `WalletTopup` intent + server-signed (HMAC) form; the app posts it to eSewa.
- **Idempotent credit**: `creditOnce` flips intent status via a conditional update keyed on a unique `providerRef`, so concurrent verify / app-resume / cron triggers credit exactly once.
- **Reconciliation** (`payments-reconciliation.job`, every 5 min) + app-resume + in-session verify all funnel through the same credit path. Provider is always queried before an intent is marked expired (no blind expiry).
- **Refund reversal**: full refunds auto-reverse the wallet credit; partial/ambiguous refunds are flagged for manual review.
- **Driver payouts**: `POST /drivers/payouts` (guarded); admin approves/rejects, rejection refunds the wallet.
- **Coupons** discount **rides** (booking fare), never wallet top-ups.

---

## 6. Chat architecture

- Keyed by `Booking`; a conversation exists only once the booking is **accepted** (`confirmedAt != null`).
- `ChatService.resolveAccess` gates every operation: caller must be the booking's passenger or driver; sending is allowed while `confirmed` or ≤24h after `completed` (`POST_COMPLETION_CHAT_WINDOW_MS`); reading is always allowed to participants.
- Realtime via Socket.IO namespace `/chat`, JWT-authenticated on handshake; rooms `booking:{id}` and `user:{id}`. Server emits `message`/`read`/`conversation_update`/`conversation_opened`.
- REST fallback + history: `GET/POST /chat/:bookingId/messages`, `POST /chat/:bookingId/read` (read receipts), `GET /chat/unread-count`, `GET /chat/conversations` (active + archived).
- Moderation/rate-limit/fraud hooks run on send. **Archive/soft-delete per-user is not yet exposed as an endpoint** (listed as a future enhancement).

---

## 7. Delete Account lifecycle

`active → pending_deletion → deleted`, with admin-gated reactivation. Business rules:

1. `POST /users/me/deletion/request-otp` → OTP (namespaced `action_otp:delete:{userId}`).
2. `POST /users/me/deletion/confirm` (OTP) → `accountStatus = pending_deletion`, `deletionRequestedAt = now`. `isActive` stays true: the user may **log in and browse** for the 30-day grace period.
3. During grace, `PendingDeletionGuard` returns 403 on book / post ride / accept / top-up / payout. Reads stay open. **Logging in never cancels** the deletion.
4. `POST /users/me/deletion/cancel` → back to `active`.
5. `account-deletion.job` (daily 03:00) flips `pending_deletion` older than 30 days to `deleted`, sets `isActive=false`, revokes sessions. **Data is retained** (phone kept) to detect reuse and allow restore.
6. **Reactivation**: a deleted phone attempting `verify-otp` raises an idempotent `ReactivationRequest` and is blocked. Admin `/admin/reactivations` approve **restores the original account** (continuity + full history) or reject keeps it deleted with a reason. Both notify + audit.

---

## 8. Coupon engine

- All discount math is **server-side** (`CouponsService.quote`) — the client only submits a code and displays the returned figure.
- Validation gates: active, `validFrom/validUntil` window, audience (`all|passenger|driver`), `minAmount`, global `usageLimit`, `perUserLimit` (counted from non-reversed redemptions), percentage cap, and clamp so payable never goes negative.
- **Booking integration**: `bookings.create` recomputes the discount from the stored coupon, sets `discountAmount`/`totalAmount`, and ledgers a `CouponRedemption` (`@@unique([bookingId])`). Cancel / reject (single + bulk) / expiry all call `reverseForBooking`, so reversed redemptions stop counting against limits.
- **Admin CRUD** `/admin/coupons` (+ `:id/redemptions`); delete is a soft-disable to preserve history.

---

## 9. Admin architecture

- React SPA, phone-OTP login, role-gated (`admin`, `super_admin`).
- Guard chain on every `/admin/*` route: `JwtAuthGuard → AdminIpGuard → AdminGuard` (super-admin-only routes add `SuperAdminGuard`). Admin sessions are short-lived; TOTP MFA supported/enforceable (`ADMIN_MFA_REQUIRED`), optional IP allowlist (`ADMIN_IP_ALLOWLIST`), inactivity timeout.
- Surfaces: dashboard KPIs, user/driver/vehicle moderation, trips/bookings, payouts, SOS, reports, **coupons, Contact Us tickets, issue reports, reactivation requests**, config, audit logs, fraud monitor, admin management.
- Every privileged action writes an `AuditLog` row (actor, action, target, details).

---

## 10. Security architecture (summary)

Detail in §Security Audit report and `PAYMENT_SECURITY.md`. Layers:
- **AuthN**: phone-OTP + JWT (pinned iss/aud, 15-min) + opaque rotating refresh (hashed at rest, family revocation) + optional admin TOTP.
- **AuthZ**: per-request DB re-load; ownership checks on every user-scoped resource (no IDOR); role guards on admin; `PendingDeletionGuard` on the deletion grace period.
- **Input**: global `ValidationPipe` (whitelist strips unknown fields → mass-assignment defense; transform coerces types); DTO validators everywhere; Prisma parameterization (no raw SQL → no SQLi).
- **Uploads**: UUID filenames, MIME whitelist + post-write magic-byte verification, size caps, KYC to private storage behind signed URLs; support attachments restricted to server-issued `/uploads` paths.
- **Abuse**: layered OTP rate limits + route throttling; single-use OTPs (replay-safe); fraud scoring + `FraudEvent` ledger; `SecurityAlertsService` webhooks.
- **Secrets**: pepper/HMAC/AES keys via env or a secrets provider (Azure Key Vault); rotation runbook.

---

## 11. Cron jobs (`@nestjs/schedule`)

| Job | Schedule | Purpose |
|---|---|---|
| `booking-expiry.job` | every minute | Expire stale pending bookings; reverse coupon redemptions |
| `payments-reconciliation.job` | every 5 min | Reconcile pending/stale eSewa intents; process refunds |
| `account-deletion.job` | daily 03:00 | Finalize `pending_deletion` → `deleted` after 30 days |
| `data-retention.job` | scheduled | Enforce data-retention policy |

`ScheduleModule.forRoot()` is bootstrapped globally.

---

## 12. Test & quality gates

- Unit: Jest (`npm test`) — 58 tests.
- E2E harnesses (`yatrago-api/scripts/*.mjs`, drive the live API): `de2e` (delete/reactivation, 63), `nfe2e` (coupons/EC/support/prefs/privacy, 51), `bc2e` (booking×coupon, 8), `rc2e` (ride+chat, 16). Run with raised throttle envs (see `DEPLOYMENT.md`).
- Static: `tsc --noEmit` (API + admin), `flutter analyze` (0 errors).
