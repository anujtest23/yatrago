import { useState } from 'react';
import { totpSetup, totpEnable, totpDisable } from '../api/auth';
import { errorMessage } from '../api/client';
import { useAuth } from '../auth/AuthContext';
import { Button, Card, ErrorState, PageHeader } from '../components/ui';

/**
 * Per-admin MFA management. Enrolling shows the secret + otpauth URL (to be
 * entered/scanned in an authenticator app) and requires a confirming code to
 * enable. Because the console cannot know enrollment state without a probe,
 * the page lets the admin attempt setup; the backend rejects if already on.
 */
export default function Security() {
  const { user } = useAuth();
  const [secret, setSecret] = useState<string | null>(null);
  const [otpauthUrl, setOtpauthUrl] = useState<string | null>(null);
  const [code, setCode] = useState('');
  const [disableCode, setDisableCode] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  const beginSetup = async () => {
    setError(null);
    setNotice(null);
    setBusy(true);
    try {
      const res = await totpSetup();
      setSecret(res.secret);
      setOtpauthUrl(res.otpauthUrl);
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setBusy(false);
    }
  };

  const enable = async () => {
    setError(null);
    setBusy(true);
    try {
      await totpEnable(code.trim());
      setNotice('MFA enabled. It will be required at your next login.');
      setSecret(null);
      setOtpauthUrl(null);
      setCode('');
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setBusy(false);
    }
  };

  const disable = async () => {
    setError(null);
    setBusy(true);
    try {
      await totpDisable(disableCode.trim());
      setNotice('MFA disabled.');
      setDisableCode('');
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setBusy(false);
    }
  };

  return (
    <>
      <PageHeader
        title="Security"
        subtitle="Two-factor authentication for your admin account"
      />

      {error && (
        <div className="mb-4">
          <ErrorState message={error} />
        </div>
      )}
      {notice && (
        <div className="mb-4 rounded-lg border border-emerald-200 bg-emerald-50 px-3 py-2 text-sm text-emerald-700">
          {notice}
        </div>
      )}

      <div className="grid max-w-2xl gap-4">
        <Card>
          <h3 className="mb-1 text-base font-semibold text-slate-900">
            Enable authenticator app (TOTP)
          </h3>
          <p className="mb-4 text-sm text-slate-500">
            Signed in as {user?.fullName ?? user?.phoneNumber}. Enrolling adds a
            required 6-digit code at every login.
          </p>

          {!secret ? (
            <Button onClick={beginSetup} disabled={busy}>
              {busy ? 'Preparing…' : 'Begin setup'}
            </Button>
          ) : (
            <div className="space-y-3">
              <div className="rounded-lg border border-slate-200 bg-slate-50 p-3">
                <p className="text-xs font-medium text-slate-500">
                  Add this secret to your authenticator app:
                </p>
                <p className="mt-1 break-all font-mono text-sm text-slate-900">
                  {secret}
                </p>
                <p className="mt-2 break-all text-xs text-slate-400">
                  {otpauthUrl}
                </p>
              </div>
              <div>
                <label className="mb-1 block text-sm font-medium text-slate-700">
                  Enter the current 6-digit code to confirm
                </label>
                <input
                  type="text"
                  inputMode="numeric"
                  value={code}
                  onChange={(e) => setCode(e.target.value)}
                  placeholder="123456"
                  className="w-40 rounded-lg border border-slate-300 px-3 py-2 text-center tracking-[0.3em] outline-none focus:border-slate-900 focus:ring-1 focus:ring-slate-900"
                />
              </div>
              <Button onClick={enable} disabled={busy}>
                {busy ? 'Enabling…' : 'Enable MFA'}
              </Button>
            </div>
          )}
        </Card>

        <Card>
          <h3 className="mb-1 text-base font-semibold text-slate-900">
            Disable MFA
          </h3>
          <p className="mb-4 text-sm text-slate-500">
            Enter a current code to turn MFA off. Only do this if you are
            changing authenticator devices.
          </p>
          <div className="flex items-end gap-3">
            <input
              type="text"
              inputMode="numeric"
              value={disableCode}
              onChange={(e) => setDisableCode(e.target.value)}
              placeholder="123456"
              className="w-40 rounded-lg border border-slate-300 px-3 py-2 text-center tracking-[0.3em] outline-none focus:border-slate-900 focus:ring-1 focus:ring-slate-900"
            />
            <Button variant="danger" onClick={disable} disabled={busy}>
              Disable
            </Button>
          </div>
        </Card>
      </div>
    </>
  );
}
