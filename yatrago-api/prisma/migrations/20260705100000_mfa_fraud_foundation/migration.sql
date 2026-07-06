-- Admin TOTP MFA fields (secret stored AES-256-GCM encrypted) and the
-- fraud-scoring foundation (cumulative score + event ledger).

ALTER TABLE "users"
  ADD COLUMN "totp_secret" TEXT,
  ADD COLUMN "totp_enabled_at" TIMESTAMP(3),
  ADD COLUMN "fraud_score" INTEGER NOT NULL DEFAULT 0;

CREATE TABLE "fraud_events" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "type" TEXT NOT NULL,
    "score" INTEGER NOT NULL,
    "details" JSONB,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "fraud_events_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "fraud_events_user_id_idx" ON "fraud_events"("user_id");
CREATE INDEX "fraud_events_type_idx" ON "fraud_events"("type");

ALTER TABLE "fraud_events" ADD CONSTRAINT "fraud_events_user_id_fkey"
  FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
