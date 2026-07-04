-- CreateEnum
CREATE TYPE "UserMode" AS ENUM ('passenger', 'driver');

-- CreateEnum
CREATE TYPE "Gender" AS ENUM ('male', 'female', 'other', 'prefer_not_to_say');

-- CreateEnum
CREATE TYPE "VerificationStatus" AS ENUM ('not_submitted', 'under_review', 'approved', 'rejected');

-- CreateEnum
CREATE TYPE "DocType" AS ENUM ('citizenship_front', 'citizenship_back', 'license_front', 'license_back', 'selfie', 'bluebook', 'insurance');

-- CreateEnum
CREATE TYPE "DocStatus" AS ENUM ('pending', 'approved', 'rejected');

-- CreateEnum
CREATE TYPE "VehicleType" AS ENUM ('motorcycle', 'car', 'suv', 'microbus');

-- CreateEnum
CREATE TYPE "RideStatus" AS ENUM ('published', 'in_progress', 'completed', 'cancelled');

-- CreateEnum
CREATE TYPE "SmokingPref" AS ENUM ('no_smoking', 'smoking_ok');

-- CreateEnum
CREATE TYPE "LuggagePref" AS ENUM ('no_luggage', 'small_only', 'any');

-- CreateEnum
CREATE TYPE "BookingStatus" AS ENUM ('pending', 'confirmed', 'rejected', 'cancelled', 'completed');

-- CreateEnum
CREATE TYPE "PaymentStatus" AS ENUM ('pending', 'paid', 'refunded', 'failed');

-- CreateEnum
CREATE TYPE "PaymentMethod" AS ENUM ('cash', 'esewa', 'khalti');

-- CreateEnum
CREATE TYPE "RateeType" AS ENUM ('driver', 'passenger');

-- CreateEnum
CREATE TYPE "NotifType" AS ENUM ('booking_confirmed', 'booking_rejected', 'ride_reminder', 'trip_started', 'trip_completed', 'payment_received', 'promotion', 'system');

-- CreateEnum
CREATE TYPE "Platform" AS ENUM ('android', 'ios');

-- CreateEnum
CREATE TYPE "ReportStatus" AS ENUM ('open', 'investigating', 'resolved', 'dismissed');

-- CreateTable
CREATE TABLE "users" (
    "id" TEXT NOT NULL,
    "phone_number" TEXT NOT NULL,
    "full_name" TEXT,
    "profile_photo_url" TEXT,
    "gender" "Gender",
    "date_of_birth" TIMESTAMP(3),
    "language" TEXT NOT NULL DEFAULT 'ne',
    "active_mode" "UserMode" NOT NULL DEFAULT 'passenger',
    "is_verified" BOOLEAN NOT NULL DEFAULT false,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "auth_sessions" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "refresh_token" TEXT NOT NULL,
    "device_info" TEXT,
    "expires_at" TIMESTAMP(3) NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "auth_sessions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "driver_profiles" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "verification_status" "VerificationStatus" NOT NULL DEFAULT 'not_submitted',
    "average_rating" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "total_trips" INTEGER NOT NULL DEFAULT 0,
    "acceptance_rate" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "completion_rate" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "cancellation_rate" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "rejection_reason" TEXT,
    "verified_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "driver_profiles_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "driver_documents" (
    "id" TEXT NOT NULL,
    "driver_id" TEXT NOT NULL,
    "doc_type" "DocType" NOT NULL,
    "file_url" TEXT NOT NULL,
    "status" "DocStatus" NOT NULL DEFAULT 'pending',
    "rejection_reason" TEXT,
    "reviewed_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "driver_documents_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "vehicles" (
    "id" TEXT NOT NULL,
    "driver_id" TEXT NOT NULL,
    "make" TEXT NOT NULL,
    "model" TEXT NOT NULL,
    "year" INTEGER NOT NULL,
    "plate_number" TEXT NOT NULL,
    "color" TEXT,
    "vehicle_type" "VehicleType" NOT NULL DEFAULT 'car',
    "total_seats" INTEGER NOT NULL DEFAULT 4,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "vehicles_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "vehicle_documents" (
    "id" TEXT NOT NULL,
    "vehicle_id" TEXT NOT NULL,
    "doc_type" "DocType" NOT NULL,
    "file_url" TEXT NOT NULL,
    "status" "DocStatus" NOT NULL DEFAULT 'pending',
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "vehicle_documents_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "rides" (
    "id" TEXT NOT NULL,
    "driver_id" TEXT NOT NULL,
    "vehicle_id" TEXT NOT NULL,
    "origin_name" TEXT NOT NULL,
    "origin_lat" DOUBLE PRECISION NOT NULL,
    "origin_lng" DOUBLE PRECISION NOT NULL,
    "dest_name" TEXT NOT NULL,
    "dest_lat" DOUBLE PRECISION NOT NULL,
    "dest_lng" DOUBLE PRECISION NOT NULL,
    "departure_at" TIMESTAMP(3) NOT NULL,
    "total_seats" INTEGER NOT NULL,
    "available_seats" INTEGER NOT NULL,
    "price_per_seat" DOUBLE PRECISION NOT NULL,
    "status" "RideStatus" NOT NULL DEFAULT 'published',
    "women_only" BOOLEAN NOT NULL DEFAULT false,
    "smoking_pref" "SmokingPref" NOT NULL DEFAULT 'no_smoking',
    "luggage_pref" "LuggagePref" NOT NULL DEFAULT 'any',
    "notes" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,
    "started_at" TIMESTAMP(3),
    "completed_at" TIMESTAMP(3),

    CONSTRAINT "rides_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ride_stops" (
    "id" TEXT NOT NULL,
    "ride_id" TEXT NOT NULL,
    "location_name" TEXT NOT NULL,
    "lat" DOUBLE PRECISION NOT NULL,
    "lng" DOUBLE PRECISION NOT NULL,
    "stop_order" INTEGER NOT NULL,
    "minutes_from_start" INTEGER,

    CONSTRAINT "ride_stops_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "bookings" (
    "id" TEXT NOT NULL,
    "ride_id" TEXT NOT NULL,
    "passenger_id" TEXT NOT NULL,
    "seats_booked" INTEGER NOT NULL DEFAULT 1,
    "total_amount" DOUBLE PRECISION NOT NULL,
    "status" "BookingStatus" NOT NULL DEFAULT 'pending',
    "payment_status" "PaymentStatus" NOT NULL DEFAULT 'pending',
    "coupon_code" TEXT,
    "discount_amount" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "cancellation_reason" TEXT,
    "booked_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "confirmed_at" TIMESTAMP(3),
    "cancelled_at" TIMESTAMP(3),
    "completed_at" TIMESTAMP(3),

    CONSTRAINT "bookings_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "payments" (
    "id" TEXT NOT NULL,
    "booking_id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "amount" DOUBLE PRECISION NOT NULL,
    "method" "PaymentMethod" NOT NULL,
    "status" "PaymentStatus" NOT NULL DEFAULT 'pending',
    "gateway_ref" TEXT,
    "gateway_response" JSONB,
    "initiated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "completed_at" TIMESTAMP(3),

    CONSTRAINT "payments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "payouts" (
    "id" TEXT NOT NULL,
    "driver_id" TEXT NOT NULL,
    "gross_amount" DOUBLE PRECISION NOT NULL,
    "commission_rate" DOUBLE PRECISION NOT NULL,
    "commission_amount" DOUBLE PRECISION NOT NULL,
    "net_amount" DOUBLE PRECISION NOT NULL,
    "method" TEXT NOT NULL,
    "account_reference" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'pending',
    "failure_reason" TEXT,
    "requested_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "processed_at" TIMESTAMP(3),

    CONSTRAINT "payouts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ratings" (
    "id" TEXT NOT NULL,
    "booking_id" TEXT NOT NULL,
    "rater_id" TEXT NOT NULL,
    "ratee_id" TEXT NOT NULL,
    "ratee_type" "RateeType" NOT NULL,
    "score" INTEGER NOT NULL,
    "review_text" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ratings_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "messages" (
    "id" TEXT NOT NULL,
    "booking_id" TEXT NOT NULL,
    "sender_id" TEXT NOT NULL,
    "receiver_id" TEXT NOT NULL,
    "content" TEXT NOT NULL,
    "is_read" BOOLEAN NOT NULL DEFAULT false,
    "sent_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "messages_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "notifications" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "type" "NotifType" NOT NULL,
    "title" TEXT NOT NULL,
    "body" TEXT NOT NULL,
    "data" JSONB,
    "is_read" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "notifications_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "device_tokens" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "fcm_token" TEXT NOT NULL,
    "platform" "Platform" NOT NULL,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "device_tokens_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "emergency_contacts" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "full_name" TEXT NOT NULL,
    "phone_number" TEXT NOT NULL,
    "relationship" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "emergency_contacts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "user_reports" (
    "id" TEXT NOT NULL,
    "reporter_id" TEXT NOT NULL,
    "reported_id" TEXT NOT NULL,
    "booking_id" TEXT,
    "reason" TEXT NOT NULL,
    "description" TEXT,
    "status" "ReportStatus" NOT NULL DEFAULT 'open',
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "resolved_at" TIMESTAMP(3),

    CONSTRAINT "user_reports_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "driver_rewards" (
    "id" TEXT NOT NULL,
    "driver_id" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "amount" DOUBLE PRECISION NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'pending',
    "earned_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "driver_rewards_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "users_phone_number_key" ON "users"("phone_number");

-- CreateIndex
CREATE UNIQUE INDEX "auth_sessions_refresh_token_key" ON "auth_sessions"("refresh_token");

-- CreateIndex
CREATE UNIQUE INDEX "driver_profiles_user_id_key" ON "driver_profiles"("user_id");

-- CreateIndex
CREATE UNIQUE INDEX "driver_documents_driver_id_doc_type_key" ON "driver_documents"("driver_id", "doc_type");

-- CreateIndex
CREATE UNIQUE INDEX "vehicles_plate_number_key" ON "vehicles"("plate_number");

-- CreateIndex
CREATE UNIQUE INDEX "ride_stops_ride_id_stop_order_key" ON "ride_stops"("ride_id", "stop_order");

-- CreateIndex
CREATE UNIQUE INDEX "bookings_ride_id_passenger_id_key" ON "bookings"("ride_id", "passenger_id");

-- CreateIndex
CREATE UNIQUE INDEX "ratings_booking_id_rater_id_key" ON "ratings"("booking_id", "rater_id");

-- CreateIndex
CREATE UNIQUE INDEX "device_tokens_fcm_token_key" ON "device_tokens"("fcm_token");

-- AddForeignKey
ALTER TABLE "auth_sessions" ADD CONSTRAINT "auth_sessions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "driver_profiles" ADD CONSTRAINT "driver_profiles_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "driver_documents" ADD CONSTRAINT "driver_documents_driver_id_fkey" FOREIGN KEY ("driver_id") REFERENCES "driver_profiles"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "vehicles" ADD CONSTRAINT "vehicles_driver_id_fkey" FOREIGN KEY ("driver_id") REFERENCES "driver_profiles"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "vehicle_documents" ADD CONSTRAINT "vehicle_documents_vehicle_id_fkey" FOREIGN KEY ("vehicle_id") REFERENCES "vehicles"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "rides" ADD CONSTRAINT "rides_driver_id_fkey" FOREIGN KEY ("driver_id") REFERENCES "driver_profiles"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "rides" ADD CONSTRAINT "rides_vehicle_id_fkey" FOREIGN KEY ("vehicle_id") REFERENCES "vehicles"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ride_stops" ADD CONSTRAINT "ride_stops_ride_id_fkey" FOREIGN KEY ("ride_id") REFERENCES "rides"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "bookings" ADD CONSTRAINT "bookings_ride_id_fkey" FOREIGN KEY ("ride_id") REFERENCES "rides"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "bookings" ADD CONSTRAINT "bookings_passenger_id_fkey" FOREIGN KEY ("passenger_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "payments" ADD CONSTRAINT "payments_booking_id_fkey" FOREIGN KEY ("booking_id") REFERENCES "bookings"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "payouts" ADD CONSTRAINT "payouts_driver_id_fkey" FOREIGN KEY ("driver_id") REFERENCES "driver_profiles"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ratings" ADD CONSTRAINT "ratings_booking_id_fkey" FOREIGN KEY ("booking_id") REFERENCES "bookings"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ratings" ADD CONSTRAINT "ratings_rater_id_fkey" FOREIGN KEY ("rater_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ratings" ADD CONSTRAINT "ratings_ratee_id_fkey" FOREIGN KEY ("ratee_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "messages" ADD CONSTRAINT "messages_booking_id_fkey" FOREIGN KEY ("booking_id") REFERENCES "bookings"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "messages" ADD CONSTRAINT "messages_sender_id_fkey" FOREIGN KEY ("sender_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "device_tokens" ADD CONSTRAINT "device_tokens_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "emergency_contacts" ADD CONSTRAINT "emergency_contacts_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_reports" ADD CONSTRAINT "user_reports_reporter_id_fkey" FOREIGN KEY ("reporter_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_reports" ADD CONSTRAINT "user_reports_reported_id_fkey" FOREIGN KEY ("reported_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_reports" ADD CONSTRAINT "user_reports_booking_id_fkey" FOREIGN KEY ("booking_id") REFERENCES "bookings"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "driver_rewards" ADD CONSTRAINT "driver_rewards_driver_id_fkey" FOREIGN KEY ("driver_id") REFERENCES "driver_profiles"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
