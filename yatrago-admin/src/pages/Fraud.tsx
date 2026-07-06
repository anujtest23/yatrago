import { useState } from 'react';
import {
  getFlaggedUsers,
  getFraudEvents,
  type FlaggedUser,
  type FraudEvent,
} from '../api/admin';
import { dateTime } from '../lib/format';
import { useAsync } from '../lib/useAsync';
import {
  Card,
  EmptyState,
  ErrorState,
  PageHeader,
  Spinner,
  StatusBadge,
} from '../components/ui';
import { TBody, TD, THead, TR, Table } from '../components/Table';

function scoreTone(score: number): string {
  if (score >= 80) return 'text-rose-600';
  if (score >= 50) return 'text-amber-600';
  return 'text-slate-700';
}

export default function Fraud() {
  const { data, loading, error } = useAsync(() => getFlaggedUsers(), []);
  const [selected, setSelected] = useState<FlaggedUser | null>(null);
  const [events, setEvents] = useState<FraudEvent[] | null>(null);
  const [eventsError, setEventsError] = useState<string | null>(null);

  const openEvents = async (u: FlaggedUser) => {
    setSelected(u);
    setEvents(null);
    setEventsError(null);
    try {
      const res = await getFraudEvents(u.id);
      setEvents(res.events);
    } catch {
      setEventsError('Failed to load fraud events');
    }
  };

  return (
    <>
      <PageHeader
        title="Fraud Monitoring"
        subtitle="Accounts with elevated fraud scores — review before action"
      />

      <Card>
        {loading && <Spinner />}
        {error && <ErrorState message={error} />}
        {data && data.users.length === 0 && (
          <EmptyState message="No flagged accounts. All clear." />
        )}
        {data && data.users.length > 0 && (
          <Table>
            <THead cols={['User', 'Role', 'Score', 'Status', '']} />
            <TBody>
              {data.users.map((u) => (
                <TR key={u.id}>
                  <TD>
                    <p className="font-medium text-slate-900">
                      {u.fullName ?? '—'}
                    </p>
                    <p className="text-xs text-slate-400">{u.phoneNumber}</p>
                  </TD>
                  <TD className="capitalize">{u.role}</TD>
                  <TD className={`font-semibold ${scoreTone(u.fraudScore)}`}>
                    {u.fraudScore}
                  </TD>
                  <TD>
                    <StatusBadge status={u.isActive ? 'active' : 'suspended'} />
                  </TD>
                  <TD>
                    <button
                      onClick={() => openEvents(u)}
                      className="text-sm font-medium text-slate-600 hover:text-slate-900"
                    >
                      View events
                    </button>
                  </TD>
                </TR>
              ))}
            </TBody>
          </Table>
        )}
      </Card>

      {selected && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4"
          onClick={() => setSelected(null)}
        >
          <div
            className="w-full max-w-lg rounded-2xl bg-white p-6 shadow-xl"
            onClick={(e) => e.stopPropagation()}
          >
            <h3 className="mb-1 text-lg font-semibold text-slate-900">
              Fraud events
            </h3>
            <p className="mb-4 text-sm text-slate-500">
              {selected.fullName ?? selected.phoneNumber} · score{' '}
              {selected.fraudScore}
            </p>
            {eventsError && <ErrorState message={eventsError} />}
            {!events && !eventsError && <Spinner />}
            {events && events.length === 0 && (
              <EmptyState message="No recorded events." />
            )}
            {events && events.length > 0 && (
              <div className="max-h-80 space-y-2 overflow-y-auto">
                {events.map((ev) => (
                  <div
                    key={ev.id}
                    className="rounded-lg border border-slate-200 px-3 py-2"
                  >
                    <div className="flex items-center justify-between">
                      <span className="font-medium text-slate-800">
                        {ev.type}
                      </span>
                      <span className="text-sm font-semibold text-amber-600">
                        +{ev.score}
                      </span>
                    </div>
                    <p className="text-xs text-slate-400">
                      {dateTime(ev.createdAt)}
                    </p>
                    {ev.details && (
                      <pre className="mt-1 overflow-x-auto rounded bg-slate-50 p-2 text-xs text-slate-600">
                        {JSON.stringify(ev.details)}
                      </pre>
                    )}
                  </div>
                ))}
              </div>
            )}
            <div className="mt-4 text-right">
              <button
                onClick={() => setSelected(null)}
                className="rounded-lg px-4 py-2 text-sm font-medium text-slate-600 hover:bg-slate-100"
              >
                Close
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  );
}
