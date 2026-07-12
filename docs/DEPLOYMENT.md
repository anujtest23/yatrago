# YatraGo — Deployment Guide

Covers the three units, environment configuration, migrations, cron,
monitoring, backup, disaster recovery, and rollback. Pairs with
[`ARCHITECTURE.md`](./ARCHITECTURE.md).

---

## 1. Prerequisites

- Node.js 20+ (API + admin), Flutter SDK 3.12+ (mobile).
- PostgreSQL 15 with **PostGIS** (rides use lat/lng); Redis 7.
- eSewa merchant credentials (production `ESEWA_SECRET_KEY`/`ESEWA_PRODUCT_CODE`).
- Object storage for KYC/uploads: Cloudflare R2 (or S3-compatible) — else local disk fallback.
- SMS provider (Sparrow) credentials for OTP delivery.

Local dev datastores run as containers `yatrago-postgres` (postgis/postgis:15-3.3) and `yatrago-redis` (redis:7-alpine).

---

## 2. Environment variables

Full list + inline docs in `yatrago-api/.env.example`. Grouped:

| Group | Keys |
|---|---|
| Core | `NODE_ENV`, `PORT`, `DATABASE_URL` |
| Auth/crypto | `JWT_ACCESS_SECRET`, `JWT_REFRESH_SECRET`, `OTP_PEPPER`, `ENCRYPTION_KEY`, `FILE_SIGNING_SECRET` |
| Redis | `REDIS_HOST`, `REDIS_PORT`, `REDIS_PASSWORD` |
| Network | `TRUST_PROXY`, `CORS_ORIGINS`, `SWAGGER_ENABLED` |
| Rate limits | `THROTTLE_LIMIT` (100), `OTP_THROTTLE_LIMIT` (5), `VERIFY_THROTTLE_LIMIT` (10) — **production defaults; raise only for local e2e** |
| SMS | `SPARROW_TOKEN`, `SPARROW_FROM` |
| Maps | `GOOGLE_MAPS_API_KEY` |
| eSewa | `ESEWA_GATEWAY_URL`, `ESEWA_STATUS_URL`, `ESEWA_PRODUCT_CODE`, `ESEWA_SECRET_KEY`, `ESEWA_SUCCESS_URL`, `ESEWA_FAILURE_URL`, `ESEWA_INTENT_TTL_MINUTES`, `ESEWA_MIN_TOPUP`, `ESEWA_MAX_TOPUP` |
| Storage | `R2_ACCOUNT_ID`, `R2_ACCESS_KEY`, `R2_SECRET_KEY`, `R2_BUCKET_NAME`, `R2_PUBLIC_URL` |
| Admin hardening | `ADMIN_IP_ALLOWLIST`, `ADMIN_MFA_REQUIRED`, `ADMIN_INACTIVITY_TIMEOUT_SECONDS`, `ADMIN_CREDIT_SUPER_THRESHOLD` |
| Secrets provider | `SECRETS_PROVIDER`, `SECRETS_NAME`, `AZURE_KEY_VAULT_URL` |
| Observability/security | `GEOIP_DB_PATH`, `TOR_CHECK_ENABLED`, `SAFE_BROWSING_API_KEY`, `METRICS_TOKEN`, `SENTRY_DSN`, `SECURITY_ALERT_WEBHOOK` |

**Production must-haves**: strong unique `JWT_*`/`OTP_PEPPER`/`ENCRYPTION_KEY`/`FILE_SIGNING_SECRET`; real eSewa secrets (sandbox fallback only outside production); `SWAGGER_ENABLED` unset/false; `CORS_ORIGINS` locked to admin origin; `TRUST_PROXY` set to the real proxy ranges if behind a CDN/WAF. Secret rotation: `SECRET_ROTATION_RUNBOOK.md`.

---

## 3. Backend (`yatrago-api`)

```bash
cd yatrago-api
npm ci
npx prisma migrate deploy      # apply migrations (production)
npm run build                  # compile to dist/
node dist/src/main             # or: npm run start:prod
```

- Serve behind a reverse proxy (TLS termination, `TRUST_PROXY` matching).
- `ScheduleModule` cron runs in-process — run **one** primary instance for cron, or gate cron to a leader if horizontally scaled.
- Health: process logs "Nest application successfully started"; add a liveness probe on `/api/v1` and DB/Redis connectivity.

## 4. Admin console (`yatrago-admin`)

```bash
cd yatrago-admin
npm ci && npm run build        # static bundle in dist/
```
Serve `dist/` from any static host/CDN; point its API base at the deployed API; add the admin origin to `CORS_ORIGINS`.

## 5. Mobile app (`yatrago_app`)

```bash
cd yatrago_app
flutter pub get
flutter build apk         # or appbundle / ios
```
Set the API base URL per environment; the Socket.IO host derives from base URL minus `/api/v1`.

---

## 6. Migrations

- Dev: `npx prisma migrate dev --name <change>`.
- Prod: `npx prisma migrate deploy` (idempotent, applies pending only).
- Never edit an applied migration; add a new one. Review any migration that drops a table/column before deploy.

---

## 7. Verification after deploy

```bash
# raised throttles so the suites aren't rate-limited (local/staging only)
OTP_THROTTLE_LIMIT=100000 VERIFY_THROTTLE_LIMIT=100000 THROTTLE_LIMIT=100000 npm run start:dev
node scripts/de2e.mjs && node scripts/nfe2e.mjs && node scripts/bc2e.mjs && node scripts/rc2e.mjs
npm test          # jest
```

---

## 8. Monitoring recommendations

- **Errors**: Sentry (`SENTRY_DSN`).
- **Metrics**: Prometheus scrape on the metrics endpoint (guard with `METRICS_TOKEN`); watch OTP sends/failures/lockouts, refresh reuse, payment reconcile outcomes, cron durations.
- **Security**: route `SECURITY_ALERT_WEBHOOK` to on-call (OTP brute-force spikes, impossible travel, fraud score jumps).
- **Business**: pending-deletion queue size, reactivation backlog, unreconciled top-ups, payout backlog.
- **Infra**: Postgres connections/replication lag, Redis memory/evictions, disk for `uploads/`.

---

## 9. Backup strategy

- **Postgres**: automated daily base backup + continuous WAL archiving (PITR). Test restores monthly. Retain ≥30 days (aligns with the account-deletion grace window).
- **Redis**: it holds OTPs (ephemeral) and refresh-token blacklist/throttle counters — losing it logs users out and clears in-flight OTPs but is not data-loss-critical; enable AOF for graceful restarts.
- **Object storage** (R2/S3): versioning + lifecycle rules; KYC docs are private and encrypted-at-rest by the provider.
- **Secrets**: stored in the secrets provider, not in backups.

---

## 10. Disaster recovery

- **RPO/RTO**: target RPO ≤5 min (WAL archiving), RTO ≤1 h.
- Restore order: Postgres (PITR to last good point) → Redis (fresh is acceptable) → object storage (versioned) → redeploy API/admin from the last tagged build.
- **Payment integrity after restore**: run `payments-reconciliation.job` immediately — it re-queries eSewa for every non-final intent and credits idempotently, healing any window lost in the restore.
- Keep the eSewa provider reference (`providerRef`) uniqueness intact — it is the idempotency key that prevents double credits during replay.

---

## 11. Rollback strategy

- **App code**: deploy the previous tagged build (API + admin are stateless).
- **Schema**: prefer forward-fix. If a rollback is unavoidable, apply a new "down" migration — do **not** delete migration history. Additive migrations (this release) are safe to leave in place even if code is rolled back.
- **Feature toggle**: rate-limit and admin-hardening envs allow tightening/loosening without redeploy.
- Post-rollback, re-run the e2e suites (§7) against staging before promoting.
