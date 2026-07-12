-- CreateEnum
CREATE TYPE "payment_provider" AS ENUM ('esewa');

-- CreateEnum
CREATE TYPE "wallet_topup_status" AS ENUM ('initiated', 'pending', 'completed', 'failed', 'expired');

-- CreateTable
CREATE TABLE "wallet_topups" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "provider" "payment_provider" NOT NULL DEFAULT 'esewa',
    "amount" DOUBLE PRECISION NOT NULL,
    "total_amount" DOUBLE PRECISION NOT NULL,
    "status" "wallet_topup_status" NOT NULL DEFAULT 'initiated',
    "transaction_uuid" TEXT NOT NULL,
    "provider_ref" TEXT,
    "credited_txn_id" TEXT,
    "ip_address" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,
    "completed_at" TIMESTAMP(3),

    CONSTRAINT "wallet_topups_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "wallet_topups_transaction_uuid_key" ON "wallet_topups"("transaction_uuid");

-- CreateIndex
CREATE UNIQUE INDEX "wallet_topups_provider_ref_key" ON "wallet_topups"("provider_ref");

-- CreateIndex
CREATE INDEX "wallet_topups_user_id_idx" ON "wallet_topups"("user_id");

-- CreateIndex
CREATE INDEX "wallet_topups_status_idx" ON "wallet_topups"("status");

-- AddForeignKey
ALTER TABLE "wallet_topups" ADD CONSTRAINT "wallet_topups_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
