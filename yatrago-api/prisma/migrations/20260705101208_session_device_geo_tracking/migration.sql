-- AlterTable
ALTER TABLE "auth_sessions" ADD COLUMN     "country" TEXT,
ADD COLUMN     "device_id" TEXT,
ADD COLUMN     "geo_lat" DOUBLE PRECISION,
ADD COLUMN     "geo_lng" DOUBLE PRECISION;

-- CreateIndex
CREATE INDEX "auth_sessions_device_id_idx" ON "auth_sessions"("device_id");
