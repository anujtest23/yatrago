import { useEffect, useState } from 'react';
import { getConfig, updateConfig } from '../api/admin';
import { errorMessage } from '../api/client';
import { useAsync } from '../lib/useAsync';
import { configLabel } from '../lib/format';
import {
  Button,
  Card,
  ErrorState,
  PageHeader,
  Spinner,
} from '../components/ui';

// Short hints for the known config keys so admins understand each value.
const HINTS: Record<string, string> = {
  commission_percent: 'Commission taken as % of ride fares',
  commission_mode: '0 = percent of fares · 1 = fixed NPR per ride',
  commission_fixed: 'Flat NPR commission per ride (when mode = 1)',
  min_wallet_balance: 'Min wallet balance a driver must hold to post/accept',
  price_cap_per_km: 'Max NPR per km a ride may charge',
  full_refund_hours: 'Cancel earlier than this → 100% refund',
  half_refund_hours: 'Cancel earlier than this → 50% refund',
  min_payout_npr: 'Minimum withdrawal amount',
  booking_expiry_minutes: 'Pending bookings expire after this many minutes',
  min_departure_minutes: 'Ride must depart at least this many minutes out',
  max_departure_days: 'Ride cannot be scheduled beyond this many days',
};

export default function Config() {
  const { data, loading, error, reload } = useAsync(getConfig, []);
  const [draft, setDraft] = useState<Record<string, string>>({});
  const [savingKey, setSavingKey] = useState<string | null>(null);
  const [savedKey, setSavedKey] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);

  useEffect(() => {
    if (data) {
      const d: Record<string, string> = {};
      for (const [k, v] of Object.entries(data)) d[k] = String(v);
      setDraft(d);
    }
  }, [data]);

  const save = async (key: string) => {
    const value = Number(draft[key]);
    if (Number.isNaN(value)) {
      setActionError(`${configLabel(key)} must be a number.`);
      return;
    }
    setSavingKey(key);
    setActionError(null);
    setSavedKey(null);
    try {
      await updateConfig(key, value);
      setSavedKey(key);
      reload();
      setTimeout(() => setSavedKey(null), 2000);
    } catch (err) {
      setActionError(errorMessage(err));
    } finally {
      setSavingKey(null);
    }
  };

  return (
    <>
      <PageHeader
        title="Settings"
        subtitle="Platform-wide business rules — changes apply immediately"
      />

      {loading && <Spinner />}
      {error && <ErrorState message={error} />}
      {actionError && (
        <div className="mb-4">
          <ErrorState message={actionError} />
        </div>
      )}

      {data && (
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
          {Object.keys(data).map((key) => {
            const changed = draft[key] !== String(data[key]);
            return (
              <Card key={key} className="p-4">
                <div className="flex items-start justify-between gap-3">
                  <div className="min-w-0">
                    <p className="font-medium text-slate-800">
                      {configLabel(key)}
                    </p>
                    {HINTS[key] && (
                      <p className="mt-0.5 text-xs text-slate-400">
                        {HINTS[key]}
                      </p>
                    )}
                  </div>
                  {savedKey === key && (
                    <span className="shrink-0 text-xs font-medium text-emerald-600">
                      Saved ✓
                    </span>
                  )}
                </div>
                <div className="mt-3 flex items-center gap-2">
                  <input
                    type="number"
                    value={draft[key] ?? ''}
                    onChange={(e) =>
                      setDraft((d) => ({ ...d, [key]: e.target.value }))
                    }
                    className="w-full rounded-lg border border-slate-300 px-3 py-1.5 text-sm outline-none focus:border-slate-900"
                  />
                  <Button
                    disabled={!changed || savingKey === key}
                    onClick={() => save(key)}
                  >
                    {savingKey === key ? '…' : 'Save'}
                  </Button>
                </div>
              </Card>
            );
          })}
        </div>
      )}
    </>
  );
}
