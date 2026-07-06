import { randomBytes } from 'crypto';

/**
 * Central application configuration.
 *
 * Security posture:
 *  - Production refuses to boot without strong, explicit secrets (fail secure).
 *  - Development generates ephemeral per-boot secrets instead of shipping a
 *    hardcoded fallback, so a leaked build can never contain a usable key.
 *  - Access and refresh tokens use SEPARATE secrets so one token class can
 *    never be forged from knowledge of the other (JWT RFC 8725 §2.3).
 */

const nodeEnv = process.env.NODE_ENV ?? 'development';
const isProduction = nodeEnv === 'production';

function requireSecret(name: string, minLength = 32): string {
  const value = process.env[name];

  if (isProduction) {
    if (!value || value.length < minLength) {
      // Fail fast and loud: booting with a weak/missing secret in production
      // would silently issue forgeable tokens.
      throw new Error(
        `FATAL: ${name} must be set and at least ${minLength} characters in production.`,
      );
    }
    return value;
  }

  if (value && value.length >= minLength) return value;

  // Development only: ephemeral random secret, regenerated each boot.
  const ephemeral = randomBytes(48).toString('base64url');
  console.warn(
    `[config] ${name} missing or too short — using ephemeral dev secret (tokens reset on restart).`,
  );
  return ephemeral;
}

/**
 * Express `trust proxy` value from TRUST_PROXY:
 *   unset/'0'  → false (direct exposure — never trust X-Forwarded-For)
 *   '1'/'true' → 1 hop (single nginx/ALB in front)
 *   'N'        → N hops
 *   CSV        → explicit proxy IPs/CIDRs (Cloudflare/AWS WAF ranges), so a
 *                client can never spoof its IP by sending X-Forwarded-For
 *                through an untrusted path.
 */
function parseTrustProxy(raw?: string): boolean | number | string[] {
  const value = (raw ?? '').trim();
  if (!value || value === '0' || value.toLowerCase() === 'false') return false;
  if (value.toLowerCase() === 'true') return 1;
  if (/^\d+$/.test(value)) return parseInt(value, 10);
  return value
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
}

function requireInProduction(name: string): string {
  const value = process.env[name] ?? '';
  if (isProduction && !value) {
    throw new Error(`FATAL: ${name} must be set in production.`);
  }
  return value;
}

export const appConfig = {
  port: parseInt(process.env.PORT ?? '3000', 10),
  nodeEnv,
  isProduction,

  // ── JWT / sessions ─────────────────────────────────────────────
  // Separate signing keys per token class. JWT_SECRET is accepted as a
  // legacy fallback for the ACCESS secret only, in non-production.
  jwtAccessSecret: isProduction
    ? requireSecret('JWT_ACCESS_SECRET')
    : (process.env.JWT_ACCESS_SECRET ??
      process.env.JWT_SECRET ??
      requireSecret('JWT_ACCESS_SECRET')),
  jwtRefreshSecret: requireSecret('JWT_REFRESH_SECRET'),
  jwtIssuer: 'yatrago-api',
  jwtAudience: 'yatrago-clients',
  jwtExpiresIn: 60 * 15, // access token: 15 minutes
  refreshTokenTtlSeconds: 60 * 60 * 24 * 30, // refresh session: 30 days
  // Admin accounts hold elevated privileges — their sessions expire in
  // hours, not weeks (OWASP ASVS session management for privileged users).
  adminRefreshTtlSeconds: 60 * 60 * 12,
  maxSessionsPerUser: 5,

  // Pepper for hashing OTPs at rest in Redis. Falls back to the refresh
  // secret so a bare Redis dump alone can never reveal live OTPs.
  otpPepper: process.env.OTP_PEPPER ?? requireSecret('JWT_REFRESH_SECRET'),

  // HMAC key for signed file URLs (private KYC documents).
  fileSigningSecret:
    process.env.FILE_SIGNING_SECRET ?? requireSecret('JWT_REFRESH_SECRET'),

  // AES-256-GCM key material for field-level PII encryption.
  encryptionKey:
    process.env.ENCRYPTION_KEY ?? requireSecret('JWT_REFRESH_SECRET'),

  // Optional CSV of IPs allowed to call /admin/* (empty = disabled).
  adminIpAllowlist: (process.env.ADMIN_IP_ALLOWLIST ?? '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean),

  // Wallet credits above this need a super_admin (dual-control threshold).
  adminCreditSuperThreshold: parseInt(
    process.env.ADMIN_CREDIT_SUPER_THRESHOLD ?? '10000',
    10,
  ),

  // Admins MUST have TOTP enrolled before any /admin/* route works.
  // Enforced by default in production; opt-in elsewhere (ADMIN_MFA_REQUIRED=true).
  adminMfaRequired: isProduction
    ? process.env.ADMIN_MFA_REQUIRED !== 'false'
    : process.env.ADMIN_MFA_REQUIRED === 'true',

  // Admin sessions die after this much inactivity (no refresh), independent
  // of the 12-hour absolute cap. OWASP ASVS 3.3.2.
  adminInactivityTimeoutSeconds: parseInt(
    process.env.ADMIN_INACTIVITY_TIMEOUT_SECONDS ?? '3600',
    10,
  ),

  // ── Fraud / anomaly detection ──────────────────────────────────
  // Path to a MaxMind GeoLite2/GeoIP2 City .mmdb file. Empty = geo anomaly
  // detection disabled (lookups return null, nothing else changes).
  geoipDbPath: process.env.GEOIP_DB_PATH ?? '',
  // Refresh the Tor exit-node list in the background and fraud-score logins
  // arriving from exits. Default on in production, opt-in elsewhere.
  torCheckEnabled: isProduction
    ? process.env.TOR_CHECK_ENABLED !== 'false'
    : process.env.TOR_CHECK_ENABLED === 'true',
  // Optional Google Safe Browsing v4 key for chat URL reputation checks.
  safeBrowsingKey: process.env.SAFE_BROWSING_API_KEY ?? '',

  // ── Monitoring ─────────────────────────────────────────────────
  // Bearer token protecting GET /metrics (Prometheus scrape). Empty =
  // endpoint disabled entirely (fail closed).
  metricsToken: process.env.METRICS_TOKEN ?? '',
  sentryDsn: process.env.SENTRY_DSN ?? '',
  // Optional webhook (Slack-compatible JSON POST) for security alerts:
  // OTP attack spikes, refresh-token reuse, fraud surges.
  securityAlertWebhook: process.env.SECURITY_ALERT_WEBHOOK ?? '',

  // ── Infrastructure ─────────────────────────────────────────────
  redisHost: process.env.REDIS_HOST ?? 'localhost',
  redisPort: parseInt(process.env.REDIS_PORT ?? '6379', 10),
  redisPassword: process.env.REDIS_PASSWORD || undefined,
  // TRUST_PROXY accepts: '1'/'true' (one hop), a hop count ('2'), or a CSV
  // of proxy IPs/CIDRs ('10.0.0.0/8,173.245.48.0/20') for WAF/CDN setups.
  // Passed straight to Express's `trust proxy`; anything else is off.
  trustProxy: parseTrustProxy(process.env.TRUST_PROXY),

  // Comma-separated browser origins allowed by CORS (admin console).
  // Mobile apps send no Origin header and are unaffected.
  corsOrigins: (process.env.CORS_ORIGINS ?? 'http://localhost:5173')
    .split(',')
    .map((o) => o.trim())
    .filter(Boolean),

  swaggerEnabled: !isProduction || process.env.SWAGGER_ENABLED === 'true',

  // ── Third-party providers ──────────────────────────────────────
  sparrowToken: requireInProduction('SPARROW_TOKEN'),
  sparrowFrom: process.env.SPARROW_FROM ?? 'YatraGo',
  googleMapsKey: process.env.GOOGLE_MAPS_API_KEY ?? '',
  r2AccountId: process.env.R2_ACCOUNT_ID ?? '',
  r2AccessKey: process.env.R2_ACCESS_KEY ?? '',
  r2SecretKey: process.env.R2_SECRET_KEY ?? '',
  r2BucketName: process.env.R2_BUCKET_NAME ?? '',
  r2PublicUrl: process.env.R2_PUBLIC_URL ?? '',
};
