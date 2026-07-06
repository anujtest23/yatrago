# Secret Rotation Runbook — YatraGo / RideSathi

All application secrets live in environment variables (never in code or git).
This runbook covers rotating each one. Perform rotations from a trusted admin
host with access to the deployment's secret manager.

> Golden rule: rotate one secret at a time, deploy, verify, then move on.

## Secret inventory

| Secret | Purpose | Rotation impact |
|---|---|---|
| `JWT_ACCESS_SECRET` | Signs access tokens | All access tokens invalid → clients silently refresh. Near-zero user impact. |
| `JWT_REFRESH_SECRET` | Derives OTP pepper / file-signing / encryption fallbacks **if those are unset** | If used as a fallback, rotating it changes those too — see below. |
| `OTP_PEPPER` | HMAC pepper for OTPs in Redis | In-flight OTPs become unverifiable; users request a new OTP. Trivial impact. |
| `FILE_SIGNING_SECRET` | HMAC for signed KYC URLs | Previously issued signed URLs 404 immediately. New ones work. |
| `ENCRYPTION_KEY` | AES-256-GCM for PII columns (TOTP secrets, payout refs) | **Destructive if rotated naively** — see dedicated section. |
| `SPARROW_TOKEN` | SMS gateway | Provider-side rotation; update env and redeploy. |
| `R2_ACCESS_KEY` / `R2_SECRET_KEY` | Object storage | Create new key pair in Cloudflare, deploy, then revoke old. |
| `BACKUP_PASSPHRASE` | Encrypts DB backups | Old backups still need the OLD passphrase to restore — never discard it. |
| `DATABASE_URL` password | Postgres auth | Rotate in DB + env together. |

## Generating a strong secret

```bash
node -e "console.log(require('crypto').randomBytes(48).toString('base64url'))"
```

## Standard rotation (access secret, OTP pepper, file-signing)

These are safe to rotate directly; worst case is a one-time re-login or
re-request:

1. Generate the new value.
2. Update it in the secret manager / `.env`.
3. Deploy / restart the API (rolling restart is fine).
4. Verify: log in on a test account, request an OTP, open a KYC document in the
   admin panel.

## `JWT_REFRESH_SECRET`

Rotating this invalidates every refresh session → **all users must log in
again**. Additionally, if `OTP_PEPPER`, `FILE_SIGNING_SECRET`, or
`ENCRYPTION_KEY` are unset, they fall back to this value and will change too.

Before rotating: set `OTP_PEPPER`, `FILE_SIGNING_SECRET`, and `ENCRYPTION_KEY`
to their own explicit values (copy the current effective value first so
encrypted data stays readable — see next section). Then rotate the refresh
secret in a low-traffic window and announce the forced re-login.

## `ENCRYPTION_KEY` (careful — data at rest)

Encrypted columns (`users.totpSecret`, `payouts.accountReference`) are written
with the key active at write time. The `EncryptionService` ciphertext is
tagged `enc:v1:`, so a versioned re-encryption migration is required to change
keys:

1. Deploy code that can DECRYPT with the OLD key and ENCRYPT with the NEW key.
2. Run a one-off migration that reads each encrypted row, decrypts with old,
   re-encrypts with new, writes back.
3. Once every row is migrated, remove the old key.

Do **not** simply swap `ENCRYPTION_KEY` — existing ciphertext becomes
undecryptable (GCM auth failure) and TOTP/payout data is lost.

## `R2_ACCESS_KEY` / `R2_SECRET_KEY`

1. Create a second API token in Cloudflare R2 (scoped to the bucket).
2. Update env, deploy, verify an upload + a signed-URL fetch.
3. Revoke the old token in Cloudflare.

## After any rotation

- Confirm the API booted (it fails fast on missing/weak secrets in production).
- Watch logs for `auth.refresh_reuse_detected` spikes (expected briefly if you
  invalidated refresh tokens) and 5xx rates.
- Record the rotation date + operator in the security log.
