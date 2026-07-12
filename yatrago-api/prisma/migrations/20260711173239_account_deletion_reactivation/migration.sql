-- CreateEnum
CREATE TYPE "AccountStatus" AS ENUM ('active', 'pending_deletion', 'deleted');

-- CreateEnum
CREATE TYPE "ReactivationStatus" AS ENUM ('pending', 'approved', 'rejected');

-- AlterEnum
ALTER TYPE "wallet_topup_status" ADD VALUE 'refunded';

-- DropForeignKey
ALTER TABLE "topup_requests" DROP CONSTRAINT "topup_requests_user_id_fkey";

-- AlterTable
ALTER TABLE "users" ADD COLUMN     "account_status" "AccountStatus" NOT NULL DEFAULT 'active';

-- AlterTable
ALTER TABLE "wallet_topups" ADD COLUMN     "refunded_amount" DOUBLE PRECISION,
ADD COLUMN     "refunded_at" TIMESTAMP(3);

-- DropTable
DROP TABLE "topup_requests";

-- DropEnum
DROP TYPE "topup_request_status";

-- CreateTable
CREATE TABLE "reactivation_requests" (
    "id" TEXT NOT NULL,
    "phone_number" TEXT NOT NULL,
    "previous_user_id" TEXT NOT NULL,
    "status" "ReactivationStatus" NOT NULL DEFAULT 'pending',
    "rejection_reason" TEXT,
    "requested_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "reviewed_at" TIMESTAMP(3),
    "reviewed_by" TEXT,

    CONSTRAINT "reactivation_requests_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "reactivation_requests_status_idx" ON "reactivation_requests"("status");

-- CreateIndex
CREATE INDEX "reactivation_requests_phone_number_idx" ON "reactivation_requests"("phone_number");

-- CreateIndex
CREATE INDEX "users_account_status_idx" ON "users"("account_status");

-- AddForeignKey
ALTER TABLE "reactivation_requests" ADD CONSTRAINT "reactivation_requests_previous_user_id_fkey" FOREIGN KEY ("previous_user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

