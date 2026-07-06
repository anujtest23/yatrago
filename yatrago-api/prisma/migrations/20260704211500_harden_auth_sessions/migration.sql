-- Harden auth sessions:
--   * refresh tokens stored as SHA-256 hashes (never plaintext)
--   * rotation families for token-theft (reuse) detection
--   * device/IP metadata + last-used tracking for session management
--
-- Legacy rows hold raw refresh tokens and cannot be backfilled into hashes,
-- so all existing sessions are invalidated (one-time forced re-login).

DELETE FROM "auth_sessions";

ALTER TABLE "auth_sessions" DROP COLUMN "refresh_token";

ALTER TABLE "auth_sessions"
  ADD COLUMN "token_hash" TEXT NOT NULL,
  ADD COLUMN "family_id" TEXT NOT NULL,
  ADD COLUMN "ip_address" TEXT,
  ADD COLUMN "last_used_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;

CREATE UNIQUE INDEX "auth_sessions_token_hash_key" ON "auth_sessions"("token_hash");
CREATE INDEX "auth_sessions_user_id_idx" ON "auth_sessions"("user_id");
CREATE INDEX "auth_sessions_family_id_idx" ON "auth_sessions"("family_id");
