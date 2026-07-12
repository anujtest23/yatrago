# YatraGo — Final Security Audit (v1.0)

Whole-project review across the categories requested for acceptance. Each item
lists the control and how it was **verified** (code inspection + the live e2e
suites in `yatrago-api/scripts/*.mjs`). No blocking findings.

| # | Category | Status | Control & verification |
|---|---|---|---|
| 1 | Authentication | ✅ | Phone-OTP → 15-min JWT (pinned iss/aud) + opaque rotating refresh (SHA-256 at rest, family-revocation on reuse). Admin TOTP gate. OTPs hashed w/ pepper, 5-min TTL. Verified: jest auth suite (58 tests) + `de2e` login/deleted-token. |
| 2 | Authorization | ✅ | `JwtStrategy` re-loads user per request (rejects suspended/deleted). Role guards on `/admin/*`. `PendingDeletionGuard` on mutating routes. Verified: `de2e` (non-admin→403 on every admin path, escalation blocked), `rc2e`, `nfe2e`. |
| 3 | IDOR | ✅ | Every user-scoped resource keyed to `req.user.id`; ownership checks on contacts, tickets, issues, bookings, chat. Verified: cross-user delete of emergency contact →403/404; foreign ticket read →403; chat stranger read+send →403; issue on foreign booking blocked. |
| 4 | Input validation | ✅ | Global `ValidationPipe` `{whitelist:true, transform:true}` strips unknown fields (mass-assignment defense) + coerces types; class-validator on all DTOs. Verified: bad category/short body/invalid enum/invalid UUID all →400 in `nfe2e`. |
| 5 | SQL injection | ✅ | 100% Prisma parameterized queries — **zero** `$queryRaw`/`$executeRaw`/`queryRawUnsafe` in the codebase (grep clean). |
| 6 | XSS | ✅ | API returns JSON only. Admin is React (auto-escaping) with **no** `dangerouslySetInnerHTML` (grep clean). Upload filenames are server UUIDs (no stored-XSS via `.svg`/`.html` names). |
| 7 | CSRF | ✅ | Stateless Bearer-token auth; no cookie/session auth (grep clean) → CSRF not applicable. CORS locked to configured origins. |
| 8 | Rate limiting | ✅ | Layered: per-IP + per-phone OTP counters (Redis) + per-route `@Throttle` + global throttler. Limits env-tunable with production defaults unchanged (5/10/100). Verified: `de2e` OTP rate-limit assertion. |
| 9 | Replay attacks | ✅ | OTPs single-use (deleted on success); refresh-token reuse revokes the family; eSewa credit idempotent via unique `providerRef`. Verified: `de2e` replay assertion (consumed OTP →400). |
| 10 | File upload validation | ✅ | UUID filenames, MIME whitelist, **post-write magic-byte verification** (FileSignatureInterceptor), 5 MB cap, single file. Support attachments restricted to server-issued `/uploads/...` paths (blocks external/SSRF URLs). Verified: `nfe2e` external-URL→400, `/uploads` path accepted. |
| 11 | Payment integrity | ✅ | Server-verify-only (client never signs); idempotent `creditOnce`; reconcile re-queries provider before expiry; refund reversal with manual-review path. Detail in `PAYMENT_SECURITY.md`. Coupons discount rides only, never wallet. Verified: `bc2e` discount/redemption/reversal. |
| 12 | Account lifecycle | ✅ | `active/pending_deletion/deleted` state machine; login never cancels deletion; grace-period action gating; deleted accounts retained + admin-gated reactivation (idempotent requests, no spam). Verified: `de2e` (63 assertions across all lifecycle branches). |
| 13 | Chat authorization | ✅ | `resolveAccess` requires booking participant + accepted booking; 24h post-completion send window; JWT-authed Socket.IO handshake. Verified: `rc2e` (no chat pre-accept, stranger read/send →403). |

## Notes / accepted risks
- **Negative wallet balance** is an accepted design choice during refund reversal (recovery from provider delays), flagged as a fraud event for monitoring.
- **Chat archive / per-user soft-delete** is not implemented as an endpoint (future enhancement) — not a security gap.
- **Rate-limit override envs** exist for test convenience; production defaults are safe and must not be raised in production.
- Standard production hardening still assumed at the edge: TLS, WAF/CDN with correct `TRUST_PROXY`, secrets in the secrets provider (see `SECRET_ROTATION_RUNBOOK.md`), Swagger disabled.

**Conclusion:** No regressions introduced by phases 2–7. Security model preserved and extended (deletion gating, coupon server-authority, attachment allowlist).
