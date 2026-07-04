import { useState } from 'react';
import { approvePayout, getPayouts, rejectPayout } from '../api/admin';
import { errorMessage } from '../api/client';
import type { PayoutRow } from '../api/types';
import { useAsync } from '../lib/useAsync';
import { dateTime, npr } from '../lib/format';
import { Avatar } from '../components/Avatar';
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

const FILTERS = ['pending', 'completed', 'failed', ''];

export default function Payouts() {
  const [status, setStatus] = useState('pending');
  const { data, loading, error, reload } = useAsync(
    () => getPayouts(status || undefined),
    [status],
  );

  const [rejecting, setRejecting] = useState<PayoutRow | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);

  const onApprove = async (p: PayoutRow) => {
    if (!window.confirm(`Mark payout of ${npr(p.netAmount)} as completed?`))
      return;
    setBusyId(p.id);
    setActionError(null);
    try {
      await approvePayout(p.id);
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
        title="Payouts"
        subtitle="Driver withdrawal requests — approve or reject with refund"
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
        {data && data.payouts.length === 0 && (
          <EmptyState message="No payouts match this filter." />
        )}
        {data && data.payouts.length > 0 && (
          <Table>
            <THead
              cols={['Driver', 'Method', 'Gross', 'Net', 'Status', 'Requested', '']}
            />
            <TBody>
              {data.payouts.map((p) => (
                <TR key={p.id}>
                  <TD>
                    <div className="flex items-center gap-2">
                      <Avatar
                        name={p.driver?.user?.fullName}
                        photoUrl={p.driver?.user?.profilePhotoUrl}
                        size={28}
                      />
                      <div>
                        <p className="font-medium text-slate-900">
                          {p.driver?.user?.fullName ?? '—'}
                        </p>
                        <p className="text-xs text-slate-400">
                          {p.driver?.user?.phoneNumber}
                        </p>
                      </div>
                    </div>
                  </TD>
                  <TD className="capitalize">{p.method}</TD>
                  <TD>{npr(p.grossAmount)}</TD>
                  <TD className="font-medium">{npr(p.netAmount)}</TD>
                  <TD>
                    <StatusBadge status={p.status} />
                    {p.failureReason && (
                      <p className="mt-0.5 text-xs text-rose-500">
                        {p.failureReason}
                      </p>
                    )}
                  </TD>
                  <TD>{dateTime(p.requestedAt)}</TD>
                  <TD>
                    {p.status === 'pending' && (
                      <div className="flex justify-end gap-2">
                        <Button
                          variant="danger"
                          onClick={() => setRejecting(p)}
                        >
                          Reject
                        </Button>
                        <Button
                          variant="success"
                          disabled={busyId === p.id}
                          onClick={() => onApprove(p)}
                        >
                          {busyId === p.id ? '…' : 'Approve'}
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
        open={!!rejecting}
        title="Reject payout"
        label="Reason (funds returned to driver wallet)"
        confirmText="Reject & refund"
        onClose={() => setRejecting(null)}
        onConfirm={(reason) => rejectPayout(rejecting!.id, reason)}
        onDone={() => {
          setRejecting(null);
          reload();
        }}
      />
    </>
  );
}
