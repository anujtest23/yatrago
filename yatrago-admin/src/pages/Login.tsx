import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { sendOtp, verifyOtp, verifyMfa, verifyAdminAccess } from '../api/auth';
import { tokenStore, errorMessage } from '../api/client';
import { useAuth } from '../auth/AuthContext';
import { Button } from '../components/ui';
import type { AdminUser } from '../api/types';

export default function Login() {
  const navigate = useNavigate();
  const { setSession } = useAuth();

  const [step, setStep] = useState<'phone' | 'otp' | 'mfa'>('phone');
  const [phone, setPhone] = useState('');
  const [otp, setOtp] = useState('');
  const [mfaCode, setMfaCode] = useState('');
  const [mfaToken, setMfaToken] = useState('');
  const [devOtp, setDevOtp] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const requestOtp = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setBusy(true);
    try {
      const res = await sendOtp(phone.trim());
      setDevOtp(res.otp ?? null); // backend returns OTP only in development
      setStep('otp');
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setBusy(false);
    }
  };

  const finishLogin = async (user: AdminUser) => {
    // Gate the console: the account must actually have admin rights.
    const ok = await verifyAdminAccess();
    if (!ok) {
      tokenStore.clear();
      setError('This account does not have admin access.');
      return;
    }
    setSession(user);
    navigate('/', { replace: true });
  };

  const confirmOtp = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setBusy(true);
    try {
      const res = await verifyOtp(phone.trim(), otp.trim());
      if (res.mfaRequired && res.mfaToken) {
        setMfaToken(res.mfaToken);
        setStep('mfa');
        return;
      }
      if (res.user) await finishLogin(res.user);
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setBusy(false);
    }
  };

  const confirmMfa = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setBusy(true);
    try {
      const res = await verifyMfa(mfaToken, mfaCode.trim());
      if (res.user) await finishLogin(res.user);
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="flex min-h-full items-center justify-center bg-slate-900 p-4">
      <div className="w-full max-w-sm">
        <div className="mb-8 text-center">
          <div className="mx-auto mb-3 flex h-14 w-14 items-center justify-center rounded-2xl bg-white text-2xl font-bold text-slate-900">
            Y
          </div>
          <h1 className="text-xl font-semibold text-white">
            YatraGo Admin Console
          </h1>
          <p className="mt-1 text-sm text-slate-400">
            Sign in with your admin phone number
          </p>
        </div>

        <div className="rounded-2xl bg-white p-6 shadow-xl">
          {error && (
            <div className="mb-4 rounded-lg border border-rose-200 bg-rose-50 px-3 py-2 text-sm text-rose-700">
              {error}
            </div>
          )}

          {step === 'mfa' ? (
            <form onSubmit={confirmMfa} className="space-y-4">
              <div>
                <label className="mb-1 block text-sm font-medium text-slate-700">
                  Two-factor code
                </label>
                <p className="mb-2 text-xs text-slate-500">
                  Enter the 6-digit code from your authenticator app.
                </p>
                <input
                  type="text"
                  inputMode="numeric"
                  autoFocus
                  required
                  value={mfaCode}
                  onChange={(e) => setMfaCode(e.target.value)}
                  placeholder="6-digit code"
                  className="w-full rounded-lg border border-slate-300 px-3 py-2 text-center text-lg tracking-[0.3em] outline-none focus:border-slate-900 focus:ring-1 focus:ring-slate-900"
                />
              </div>
              <Button type="submit" disabled={busy} className="w-full">
                {busy ? 'Verifying…' : 'Verify code'}
              </Button>
            </form>
          ) : step === 'phone' ? (
            <form onSubmit={requestOtp} className="space-y-4">
              <div>
                <label className="mb-1 block text-sm font-medium text-slate-700">
                  Phone number
                </label>
                <input
                  type="tel"
                  autoFocus
                  required
                  value={phone}
                  onChange={(e) => setPhone(e.target.value)}
                  placeholder="98XXXXXXXX"
                  className="w-full rounded-lg border border-slate-300 px-3 py-2 text-sm outline-none focus:border-slate-900 focus:ring-1 focus:ring-slate-900"
                />
              </div>
              <Button type="submit" disabled={busy} className="w-full">
                {busy ? 'Sending…' : 'Send OTP'}
              </Button>
            </form>
          ) : (
            <form onSubmit={confirmOtp} className="space-y-4">
              {devOtp && (
                <div className="rounded-lg border border-amber-200 bg-amber-50 px-3 py-2 text-sm text-amber-800">
                  Dev OTP: <span className="font-mono font-semibold">{devOtp}</span>
                </div>
              )}
              <div>
                <label className="mb-1 block text-sm font-medium text-slate-700">
                  Enter OTP sent to {phone}
                </label>
                <input
                  type="text"
                  inputMode="numeric"
                  autoFocus
                  required
                  value={otp}
                  onChange={(e) => setOtp(e.target.value)}
                  placeholder="6-digit code"
                  className="w-full rounded-lg border border-slate-300 px-3 py-2 text-center text-lg tracking-[0.3em] outline-none focus:border-slate-900 focus:ring-1 focus:ring-slate-900"
                />
              </div>
              <Button type="submit" disabled={busy} className="w-full">
                {busy ? 'Verifying…' : 'Verify & Sign in'}
              </Button>
              <button
                type="button"
                onClick={() => {
                  setStep('phone');
                  setOtp('');
                  setError(null);
                }}
                className="w-full text-center text-sm text-slate-500 hover:text-slate-700"
              >
                ← Change phone number
              </button>
            </form>
          )}
        </div>
      </div>
    </div>
  );
}
