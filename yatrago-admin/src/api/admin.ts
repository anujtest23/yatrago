import { api } from './client';
import type {
  AdminAccount,
  AppConfig,
  AuditLog,
  BookingRow,
  Dashboard,
  DriverRow,
  Pagination,
  PayoutRow,
  ReportRow,
  SosRow,
  TripRow,
  UserRow,
  VehicleRow,
} from './types';

// ── Dashboard ──────────────────────────────────────────────────
export const getDashboard = () =>
  api.get<Dashboard>('/admin/dashboard').then((r) => r.data);

// ── Users ──────────────────────────────────────────────────────
export interface UsersResponse {
  users: UserRow[];
  pagination: Pagination;
}
export const getUsers = (page = 1, limit = 20, search?: string) =>
  api
    .get<UsersResponse>('/admin/users', { params: { page, limit, search } })
    .then((r) => r.data);

export const blockUser = (id: string) =>
  api.patch(`/admin/users/${id}/block`).then((r) => r.data);

export const creditWallet = (userId: string, amount: number, note?: string) =>
  api
    .post(`/admin/wallets/${userId}/credit`, { amount, note })
    .then((r) => r.data);

// ── Drivers ────────────────────────────────────────────────────
export interface DriversResponse {
  drivers: DriverRow[];
  pagination: Pagination;
}
export const getDrivers = (page = 1, limit = 20, status?: string) =>
  api
    .get<DriversResponse>('/admin/drivers', { params: { page, limit, status } })
    .then((r) => r.data);

export const approveDriver = (id: string) =>
  api.patch(`/admin/drivers/${id}/approve`).then((r) => r.data);

export const rejectDriver = (id: string, reason: string) =>
  api.patch(`/admin/drivers/${id}/reject`, { reason }).then((r) => r.data);

// ── Trips ──────────────────────────────────────────────────────
export interface TripsResponse {
  trips: TripRow[];
  pagination: Pagination;
}
export const getTrips = (page = 1, limit = 20, status?: string) =>
  api
    .get<TripsResponse>('/admin/trips', { params: { page, limit, status } })
    .then((r) => r.data);

export const forceCancelRide = (id: string) =>
  api.patch(`/admin/rides/${id}/cancel`).then((r) => r.data);

export const overrideRidePrice = (id: string, pricePerSeat: number) =>
  api.patch(`/admin/rides/${id}/price`, { pricePerSeat }).then((r) => r.data);

// ── Bookings ───────────────────────────────────────────────────
export interface BookingsResponse {
  bookings: BookingRow[];
  pagination: Pagination;
}
export const getBookings = (page = 1, limit = 20, status?: string) =>
  api
    .get<BookingsResponse>('/admin/bookings', { params: { page, limit, status } })
    .then((r) => r.data);

// ── Payouts ────────────────────────────────────────────────────
export const getPayouts = (status?: string) =>
  api
    .get<{ payouts: PayoutRow[]; total: number }>('/admin/payouts', {
      params: { status },
    })
    .then((r) => r.data);

export const approvePayout = (id: string) =>
  api.patch(`/admin/payouts/${id}/approve`).then((r) => r.data);

export const rejectPayout = (id: string, reason: string) =>
  api.patch(`/admin/payouts/${id}/reject`, { reason }).then((r) => r.data);

// ── SOS ────────────────────────────────────────────────────────
export const getSosAlerts = (status?: string) =>
  api
    .get<{ alerts: SosRow[]; total: number }>('/admin/sos', {
      params: { status },
    })
    .then((r) => r.data);

export const acknowledgeSos = (id: string) =>
  api.patch(`/admin/sos/${id}/acknowledge`).then((r) => r.data);

export const resolveSos = (id: string) =>
  api.patch(`/admin/sos/${id}/resolve`).then((r) => r.data);

// ── Reports ────────────────────────────────────────────────────
export const getReports = (status?: string) =>
  api
    .get<{ reports: ReportRow[]; total: number }>('/admin/reports', {
      params: { status },
    })
    .then((r) => r.data);

export const updateReportStatus = (id: string, status: string) =>
  api.patch(`/admin/reports/${id}/status`, { status }).then((r) => r.data);

// ── Ratings moderation (no list endpoint — act by id) ──────────
export const hideRating = (id: string, reason: string) =>
  api.patch(`/admin/ratings/${id}/hide`, { reason }).then((r) => r.data);

export const unhideRating = (id: string) =>
  api.patch(`/admin/ratings/${id}/unhide`).then((r) => r.data);

// ── Vehicles ───────────────────────────────────────────────────
export const getVehicles = (status?: string) =>
  api
    .get<{ vehicles: VehicleRow[]; total: number }>('/admin/vehicles', {
      params: { status },
    })
    .then((r) => r.data);

export const approveVehicle = (id: string) =>
  api.patch(`/admin/vehicles/${id}/approve`).then((r) => r.data);

export const rejectVehicle = (id: string, reason: string) =>
  api.patch(`/admin/vehicles/${id}/reject`, { reason }).then((r) => r.data);

// ── Config ─────────────────────────────────────────────────────
export const getConfig = () =>
  api.get<AppConfig>('/admin/config').then((r) => r.data);

export const updateConfig = (key: string, value: number) =>
  api.patch('/admin/config', { key, value }).then((r) => r.data);

// ── Admin roster (super admin only for mutations) ──────────────
export const getAdmins = () =>
  api
    .get<{ admins: AdminAccount[]; total: number }>('/admin/admins')
    .then((r) => r.data);

export const addAdmin = (phoneNumber: string, role: 'admin' | 'super_admin') =>
  api.post('/admin/admins', { phoneNumber, role }).then((r) => r.data);

export const updateAdminRole = (
  userId: string,
  role: 'admin' | 'super_admin',
) => api.patch(`/admin/admins/${userId}/role`, { role }).then((r) => r.data);

export const revokeAdmin = (userId: string) =>
  api.delete(`/admin/admins/${userId}`).then((r) => r.data);

// ── Audit logs ─────────────────────────────────────────────────
export interface AuditLogsResponse {
  logs: AuditLog[];
  pagination: Pagination;
}
export const getAuditLogs = (params: {
  actorId?: string;
  targetType?: string;
  page?: number;
  limit?: number;
}) =>
  api
    .get<AuditLogsResponse>('/admin/audit-logs', { params })
    .then((r) => r.data);
