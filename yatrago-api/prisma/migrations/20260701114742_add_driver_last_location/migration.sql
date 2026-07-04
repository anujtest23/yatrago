-- AlterTable
ALTER TABLE "driver_profiles" ADD COLUMN     "lastLat" DOUBLE PRECISION,
ADD COLUMN     "lastLng" DOUBLE PRECISION,
ADD COLUMN     "lastLocationAt" TIMESTAMP(3);
