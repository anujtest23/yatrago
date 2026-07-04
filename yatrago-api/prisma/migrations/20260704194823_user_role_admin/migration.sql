-- CreateEnum
CREATE TYPE "UserRole" AS ENUM ('user', 'admin', 'super_admin');

-- AlterTable
ALTER TABLE "users" ADD COLUMN     "role" "UserRole" NOT NULL DEFAULT 'user';
