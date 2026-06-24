export const JWT_SECRET = process.env.JWT_SECRET || 'fallback-secret';

export enum UserMode {
  PASSENGER = 'passenger',
  DRIVER = 'driver',
}

export enum VerificationStatus {
  NOT_SUBMITTED = 'not_submitted',
  UNDER_REVIEW = 'under_review',
  APPROVED = 'approved',
  REJECTED = 'rejected',
}

export enum RideStatus {
  PUBLISHED = 'published',
  IN_PROGRESS = 'in_progress',
  COMPLETED = 'completed',
  CANCELLED = 'cancelled',
}

export enum BookingStatus {
  PENDING = 'pending',
  CONFIRMED = 'confirmed',
  REJECTED = 'rejected',
  CANCELLED = 'cancelled',
  COMPLETED = 'completed',
}

export enum PaymentStatus {
  PENDING = 'pending',
  PAID = 'paid',
  REFUNDED = 'refunded',
  FAILED = 'failed',
}

export enum PaymentMethod {
  CASH = 'cash',
  ESEWA = 'esewa',
  KHALTI = 'khalti',
}

export enum NotifType {
  BOOKING_CONFIRMED = 'booking_confirmed',
  BOOKING_REJECTED = 'booking_rejected',
  RIDE_REMINDER = 'ride_reminder',
  TRIP_STARTED = 'trip_started',
  TRIP_COMPLETED = 'trip_completed',
  PAYMENT_RECEIVED = 'payment_received',
  PROMOTION = 'promotion',
  SYSTEM = 'system',
}