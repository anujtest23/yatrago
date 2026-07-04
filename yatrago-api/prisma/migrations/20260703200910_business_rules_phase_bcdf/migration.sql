-- AlterTable
ALTER TABLE "ratings" ADD COLUMN     "flag_reason" TEXT,
ADD COLUMN     "is_hidden" BOOLEAN NOT NULL DEFAULT false;

-- AlterTable
ALTER TABLE "users" ADD COLUMN     "deletion_requested_at" TIMESTAMP(3),
ADD COLUMN     "notification_settings" JSONB;
