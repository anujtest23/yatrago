-- AlterEnum
-- This migration adds more than one value to an enum.
-- With PostgreSQL versions 11 and earlier, this is not possible
-- in a single migration. This can be worked around by creating
-- multiple migrations, each migration adding only one value to
-- the enum.


ALTER TYPE "NotifType" ADD VALUE 'wallet_low';
ALTER TYPE "NotifType" ADD VALUE 'commission_charged';
ALTER TYPE "NotifType" ADD VALUE 'wallet_topup';

-- AlterTable
ALTER TABLE "bookings" ADD COLUMN     "drop_lat" DOUBLE PRECISION,
ADD COLUMN     "drop_lng" DOUBLE PRECISION,
ADD COLUMN     "drop_name" TEXT,
ADD COLUMN     "pickup_lat" DOUBLE PRECISION,
ADD COLUMN     "pickup_lng" DOUBLE PRECISION,
ADD COLUMN     "pickup_name" TEXT;

-- CreateTable
CREATE TABLE "commission_records" (
    "id" TEXT NOT NULL,
    "ride_id" TEXT NOT NULL,
    "driver_id" TEXT NOT NULL,
    "mode" TEXT NOT NULL,
    "rate" DOUBLE PRECISION NOT NULL,
    "gross_fares" DOUBLE PRECISION NOT NULL,
    "amount" DOUBLE PRECISION NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'charged',
    "note" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "commission_records_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "commission_records_driver_id_idx" ON "commission_records"("driver_id");

-- AddForeignKey
ALTER TABLE "commission_records" ADD CONSTRAINT "commission_records_ride_id_fkey" FOREIGN KEY ("ride_id") REFERENCES "rides"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "commission_records" ADD CONSTRAINT "commission_records_driver_id_fkey" FOREIGN KEY ("driver_id") REFERENCES "driver_profiles"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
