-- Wallet top-ups become admin-approved requests. Previously POST /wallet/topup
-- credited the wallet instantly with no payment behind it, letting any user
-- mint unlimited balance.

CREATE TYPE "topup_request_status" AS ENUM ('pending', 'approved', 'rejected');

CREATE TABLE "topup_requests" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "amount" DOUBLE PRECISION NOT NULL,
    "status" "topup_request_status" NOT NULL DEFAULT 'pending',
    "reference" TEXT,
    "admin_note" TEXT,
    "processed_by" TEXT,
    "processed_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "topup_requests_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "topup_requests_user_id_idx" ON "topup_requests"("user_id");
CREATE INDEX "topup_requests_status_idx" ON "topup_requests"("status");

ALTER TABLE "topup_requests" ADD CONSTRAINT "topup_requests_user_id_fkey"
  FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
