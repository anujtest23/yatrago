import { useState } from 'react';
import { getTickets, replyTicket } from '../api/admin';
import { errorMessage } from '../api/client';
import type { SupportTicketRow } from '../api/types';
import { useAsync } from '../lib/useAsync';
import { dateTime } from '../lib/format';
import { ReasonModal } from '../components/ReasonModal';
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

const FILTERS = ['open', 'in_progress', 'closed', ''];

export default function Tickets() {
  const [status, setStatus] = useState('open');
  const { data, loading, error, reload } = useAsync(
    () => getTickets(status || undefined),
    [status],
  );
  const [replying, setReplying] = useState<SupportTicketRow | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);

  const close = async (t: SupportTicketRow) => {
    setBusyId(t.id);
    setActionError(null);
    try {
      await replyTicket(t.id, { status: 'closed' });
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
        title="Contact Us"
        subtitle="Support tickets submitted by users"
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
                {f ? f.replace('_', ' ') : 'All'}
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
        {data && data.length === 0 && (
          <EmptyState message="No tickets match this filter." />
        )}
        {data && data.length > 0 && (
          <Table>
            <THead cols={['User', 'Category', 'Subject', 'Status', 'Created', '']} />
            <TBody>
              {data.map((t) => (
                <TR key={t.id}>
                  <TD>
                    <p className="font-medium text-slate-900">
                      {t.user?.fullName ?? '—'}
                    </p>
                    <p className="text-xs text-slate-400">
                      {t.user?.phoneNumber}
                    </p>
                  </TD>
                  <TD className="capitalize">{t.category}</TD>
                  <TD>
                    <p className="text-slate-900">{t.subject}</p>
                    <p className="max-w-md truncate text-xs text-slate-400">
                      {t.description}
                    </p>
                    {t.adminReply && (
                      <p className="mt-0.5 text-xs text-emerald-600">
                        Reply: {t.adminReply}
                      </p>
                    )}
                  </TD>
                  <TD>
                    <StatusBadge status={t.status} />
                  </TD>
                  <TD>{dateTime(t.createdAt)}</TD>
                  <TD>
                    {t.status !== 'closed' && (
                      <div className="flex justify-end gap-2">
                        <Button
                          disabled={busyId === t.id}
                          onClick={() => close(t)}
                        >
                          {busyId === t.id ? '…' : 'Close'}
                        </Button>
                        <Button variant="success" onClick={() => setReplying(t)}>
                          Reply
                        </Button>
                      </div>
                    )}
                  </TD>
                </TR>
              ))}
            </TBody>
          </Table>
        )}
      </Card>
      <ReasonModal
        open={!!replying}
        title="Reply to ticket"
        label="Your reply (sent to the user)"
        confirmText="Send reply"
        onClose={() => setReplying(null)}
        onConfirm={(reply) =>
          replyTicket(replying!.id, { reply, status: 'in_progress' })
        }
        onDone={() => {
          setReplying(null);
          reload();
        }}
      />
    </>
  );
}
