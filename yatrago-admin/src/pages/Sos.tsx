import { useState } from 'react';
import { acknowledgeSos, getSosAlerts, resolveSos } from '../api/admin';
import { errorMessage } from '../api/client';
import { useAsync } from '../lib/useAsync';
import { dateTime } from '../lib/format';
import { Avatar } from '../components/Avatar';
import {
  Button,
  Card,
  EmptyState,
  ErrorState,
  PageHeader,
  Spinner,
  StatusBadge,
} from '../components/ui';
import { TBody, TD, THead, TR, Table } from '../components/Table';

const FILTERS = ['open', 'acknowledged', 'resolved', ''];

export default function Sos() {
  const [status, setStatus] = useState('open');
  const { data, loading, error, reload } = useAsync(
    () => getSosAlerts(status || undefined),
    [status],
  );

  const [busyId, setBusyId] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);

  const act = async (fn: () => Promise<unknown>, id: string) => {
    setBusyId(id);
    setActionError(null);
    try {
      await fn();
      reload();
    } catch (err) {
      setActionError(errorMessage(err));
    } finally {
      setBusyId(null);
    }
  };

  return (
    <>
      <PageHeader
        title="SOS Alerts"
        subtitle="Safety alerts raised by riders — respond promptly"
        actions={
          <div className="flex gap-1 rounded-lg border border-slate-200 bg-white p-1">
            {FILTERS.map((f) => (
              <button
                key={f || 'all'}
                onClick={() => setStatus(f)}
                className={`rounded-md px-3 py-1 text-sm font-medium capitalize transition ${
                  status === f
                    ? 'bg-slate-900 text-white'
                    : 'text-slate-600 hover:bg-slate-100'
                }`}
              >
                {f || 'All'}
              </button>
            ))}
          </div>
        }
      />

      {actionError && (
        <div className="mb-4">
          <ErrorState message={actionError} />
        </div>
      )}

      <Card>
        {loading && <Spinner />}
        {error && <ErrorState message={error} />}
        {data && data.alerts.length === 0 && (
          <EmptyState message="No SOS alerts match this filter." />
        )}
        {data && data.alerts.length > 0 && (
          <Table>
            <THead cols={['User', 'Location', 'Status', 'Raised', '']} />
            <TBody>
              {data.alerts.map((a) => (
                <TR key={a.id}>
                  <TD>
                    <div className="flex items-center gap-2">
                      <Avatar
                        name={a.user?.fullName}
                        photoUrl={a.user?.profilePhotoUrl}
                        size={28}
                      />
                      <div>
                        <p className="font-medium text-slate-900">
                          {a.user?.fullName ?? '—'}
                        </p>
                        <p className="text-xs text-slate-400">
                          {a.user?.phoneNumber}
                        </p>
                      </div>
                    </div>
                  </TD>
                  <TD>
                    {a.lat != null && a.lng != null ? (
                      <a
                        href={`https://www.google.com/maps?q=${a.lat},${a.lng}`}
                        target="_blank"
                        rel="noreferrer"
                        className="text-sm font-medium text-blue-600 hover:underline"
                      >
                        View on map ↗
                      </a>
                    ) : (
                      <span className="text-slate-400">—</span>
                    )}
                  </TD>
                  <TD>
                    <StatusBadge status={a.status} />
                  </TD>
                  <TD>{dateTime(a.createdAt)}</TD>
                  <TD>
                    <div className="flex justify-end gap-2">
                      {a.status === 'open' && (
                        <Button
                          variant="secondary"
                          disabled={busyId === a.id}
                          onClick={() => act(() => acknowledgeSos(a.id), a.id)}
                        >
                          Acknowledge
                        </Button>
                      )}
                      {a.status !== 'resolved' && (
                        <Button
                          variant="success"
                          disabled={busyId === a.id}
                          onClick={() => act(() => resolveSos(a.id), a.id)}
                        >
                          {busyId === a.id ? '…' : 'Resolve'}
                        </Button>
                      )}
                    </div>
                  </TD>
                </TR>
              ))}
            </TBody>
          </Table>
        )}
      </Card>
    </>
  );
}
