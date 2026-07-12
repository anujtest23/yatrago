// Shapes returned by the NestJS admin API. Kept loose where the backend
// returns rich nested objects — we only type the fields the UI reads.

export interface Pagination {
  total: number;
  page: number;
  limit: number;
  totalPages: number;
}

export type Role = 'user' | 'admin' | 'super_admin';

export interface AdminUser {
  id: string;
  phoneNumber: string;
  fullName: string | null;
  profilePhotoUrl: string | null;
  activeMode: string | null;
  role: Role;
  isVerified: boolean;
}

export interface AdminAccount {
  id: string;
  fullName: string | null;
  phoneNumber: string;
  profilePhotoUrl: string | null;
  role: Role;
  isActive: boolean;
  createdAt: string;
}

export interface Dashboard {
  users: { total: number };
  drivers: { total: number; approved: number; pendingApproval: number };
  trips: { total: number; today: number };
  bookings: { total: number; today: number; pending: number; confirmed: number };
  revenue: { total: number; today: number };
}

export interface UserRow {
  id: string;
  phoneNumber: string;
  fullName: string | null;
  profilePhotoUrl: string | null;
  activeMode: string | null;
  isActive: boolean;
  isVerified: boolean;
  createdAt: string;
  driverProfile?: {
    verificationStatus: string;
    averageRating: number | null;
    totalTrips: number;
  } | null;
  _count?: { bookings: number };
}

export interface DriverDocument {
  docType: string;
  status: string;
  fileUrl: string | null;
  rejectionReason?: string | null;
}

export interface DriverRow {
  id: string;
  userId: string;
  verificationStatus: string;
  rejectionReason: string | null;
  averageRating: number | null;
  totalTrips: number;
  createdAt: string;
  user: {
    id: string;
    phoneNumber: string;
    fullName: string | null;
    profilePhotoUrl: string | null;
    createdAt: string;
  };
  documents: DriverDocument[];
  vehicles: {
    make: string;
    model: string;
    plateNumber: string;
    vehicleType: string;
  }[];
}

export interface TripRow {
  id: string;
  originName: string;
  destName: string;
  departureAt: string;
  pricePerSeat: number;
  availableSeats: number;
  status: string;
  createdAt: string;
  driver?: { user?: { fullName: string | null; phoneNumber: string } };
  vehicle?: { make: string; model: string; plateNumber: string } | null;
  _count?: { bookings: number };
}

export interface BookingRow {
  id: string;
  status: string;
  paymentStatus: string;
  seatsBooked: number;
  totalAmount: number;
  bookedAt: string;
  passenger?: { fullName: string | null; phoneNumber: string };
  ride?: {
    originName: string;
    destName: string;
    departureAt: string;
    pricePerSeat: number;
    driver?: { user?: { fullName: string | null; phoneNumber: string } };
  };
}

export interface CouponRow {
  id: string;
  code: string;
  description: string | null;
  discountType: 'percentage' | 'fixed';
  discountValue: number;
  maxDiscount: number | null;
  minAmount: number;
  audience: 'all' | 'passenger' | 'driver';
  usageLimit: number | null;
  perUserLimit: number | null;
  isActive: boolean;
  validFrom: string | null;
  validUntil: string | null;
  createdAt: string;
}

export interface SupportTicketRow {
  id: string;
  category: string;
  subject: string;
  description: string;
  attachments: string[];
  status: 'open' | 'in_progress' | 'closed';
  adminReply: string | null;
  createdAt: string;
  user?: { id: string; fullName: string | null; phoneNumber: string } | null;
}

export interface IssueReportRow {
  id: string;
  category: string;
  description: string;
  attachments: string[];
  status: 'open' | 'investigating' | 'resolved' | 'dismissed';
  assignedTo: string | null;
  resolution: string | null;
  bookingId: string | null;
  rideId: string | null;
  createdAt: string;
  user?: { id: string; fullName: string | null; phoneNumber: string } | null;
}

export interface ReactivationRow {
  id: string;
  phoneNumber: string;
  previousUserId: string;
  status: string;
  rejectionReason: string | null;
  requestedAt: string;
  reviewedAt: string | null;
  reviewedBy: string | null;
  previousUser?: {
    id: string;
    fullName: string | null;
    accountStatus: string;
  } | null;
}

export interface PayoutRow {
  id: string;
  status: string;
  method: string;
  grossAmount: number;
  netAmount: number;
  failureReason: string | null;
  requestedAt: string;
  processedAt: string | null;
  driver?: {
    user?: {
      id: string;
      fullName: string | null;
      phoneNumber: string;
      profilePhotoUrl: string | null;
    };
  };
}

export interface SosRow {
  id: string;
  status: string;
  lat: number | null;
  lng: number | null;
  createdAt: string;
  resolvedAt: string | null;
  user?: {
    id: string;
    fullName: string | null;
    phoneNumber: string;
    profilePhotoUrl: string | null;
  };
}

export interface ReportRow {
  id: string;
  reason: string;
  description: string | null;
  status: string;
  createdAt: string;
  resolvedAt: string | null;
  reporter?: { id: string; fullName: string | null; phoneNumber: string };
  reported?: { id: string; fullName: string | null; phoneNumber: string };
  booking?: {
    id: string;
    status: string;
    ride?: { originName: string; destName: string; departureAt: string };
  } | null;
}

export interface VehicleRow {
  id: string;
  make: string;
  model: string;
  plateNumber: string;
  vehicleType: string;
  isActive: boolean;
  createdAt: string;
  driver?: {
    user?: {
      id: string;
      fullName: string | null;
      phoneNumber: string;
      profilePhotoUrl: string | null;
    };
  };
  documents?: { docType: string; fileUrl: string | null; status: string }[];
}

export interface AuditLog {
  id: string;
  actorId: string;
  action: string;
  targetType: string;
  targetId: string;
  metadata: Record<string, unknown> | null;
  createdAt: string;
}

export type AppConfig = Record<string, number>;
