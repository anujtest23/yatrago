import { api, tokenStore } from './client';
import type { AdminUser } from './types';

export interface SendOtpResult {
  message: string;
  otp?: string; // present only when backend runs in development
}

export interface VerifyOtpResult {
  message: string;
  isNewUser?: boolean;
  // Present only when the account has MFA enrolled — no tokens are issued
  // until the second factor is verified.
  mfaRequired?: boolean;
  mfaToken?: string;
  accessToken?: string;
  refreshToken?: string;
  user?: AdminUser;
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
  // MFA-enrolled accounts return no tokens here; caller routes to the TOTP
  // step. Only store a session when tokens are actually present.
  if (data.accessToken && data.refreshToken && data.user) {
    tokenStore.set(data.accessToken, data.refreshToken, data.user);
  }
  return data;
}

export async function verifyMfa(
  mfaToken: string,
  code: string,
): Promise<VerifyOtpResult> {
  const res = await api.post('/auth/totp/verify', { mfaToken, code });
  const data = res.data as VerifyOtpResult;
  if (data.accessToken && data.refreshToken && data.user) {
    tokenStore.set(data.accessToken, data.refreshToken, data.user);
  }
  return data;
}

// ── TOTP MFA management (for the logged-in admin) ──────────────
export interface TotpSetupResult {
  secret: string;
  otpauthUrl: string;
  message: string;
}
export const totpSetup = () =>
  api.post<TotpSetupResult>('/auth/totp/setup').then((r) => r.data);

export const totpEnable = (code: string) =>
  api.post('/auth/totp/enable', { code }).then((r) => r.data);

export const totpDisable = (code: string) =>
  api.post('/auth/totp/disable', { code }).then((r) => r.data);

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
