import { api, tokenStore } from './client';
import type { AdminUser } from './types';

export interface SendOtpResult {
  message: string;
  otp?: string; // present only when backend runs in development
}

export interface VerifyOtpResult {
  message: string;
  isNewUser: boolean;
  accessToken: string;
  refreshToken: string;
  user: AdminUser;
}

export async function sendOtp(phoneNumber: string): Promise<SendOtpResult> {
  const res = await api.post('/auth/send-otp', { phoneNumber });
  return res.data;
}

export async function verifyOtp(
  phoneNumber: string,
  otp: string,
): Promise<VerifyOtpResult> {
  const res = await api.post('/auth/verify-otp', { phoneNumber, otp });
  const data = res.data as VerifyOtpResult;
  tokenStore.set(data.accessToken, data.refreshToken, data.user);
  return data;
}

export async function logout(): Promise<void> {
  const refreshToken = tokenStore.refresh;
  try {
    if (refreshToken) await api.post('/auth/logout', { refreshToken });
  } finally {
    tokenStore.clear();
  }
}

// Confirms the stored token is still valid AND that this account has admin
// rights (any /admin/* call is gated by AdminGuard). Used on app boot.
export async function verifyAdminAccess(): Promise<boolean> {
  try {
    await api.get('/admin/dashboard');
    return true;
  } catch {
    return false;
  }
}
