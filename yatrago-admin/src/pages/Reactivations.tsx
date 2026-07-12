import { useState } from 'react';
import {
  approveReactivation,
  getReactivations,
  rejectReactivation,
} from '../api/admin';
import { errorMessage } from '../api/client';
import type { ReactivationRow } from '../api/types';
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

const FILTERS = ['pending', 'approved', 'rejected', ''];

export default function Reactivations() {
  const [status, setStatus] = useState('pending');
  const { data, loading, error, reload } = useAsync(
    () => getReactivations(status || undefined),
    [status],
  );

  const [rejecting, setRejecting] = useState<ReactivationRow | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);

  const onApprove = async (r: ReactivationRow) => {
    if (
      !window.confirm(
        `Approve reactivation for ${r.phoneNumber}? This restores the previous account.`,
      )
    )
      return;
    setBusyId(r.id);
    setActionError(null);
    try {
      await approveReactivation(r.id);
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
        title="Reactivation Requests"
        subtitle="Previously-deleted numbers attempting to sign in — approve to restore the account"
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
        {data && data.length === 0 && (
          <EmptyState message="No reactivation requests match this filter." />
        )}
        {data && data.length > 0 && (
          <Table>
            <THead
              cols={['Phone', 'Previous Account', 'Status', 'Requested', '']}
            />
            <TBody>
              {data.map((r) => (
                <TR key={r.id}>
                  <TD className="font-medium text-slate-900">
                    {r.phoneNumber}
                  </TD>
                  <TD>
                    <p className="text-slate-900">
                      {r.previousUser?.fullName ?? '—'}
                    </p>
                    <p className="text-xs text-slate-400">
                      {r.previousUser?.accountStatus ?? ''}
                    </p>
                  </TD>
                  <TD>
                    <StatusBadge status={r.status} />
                    {r.rejectionReason && (
                      <p className="mt-0.5 text-xs text-rose-500">
                        {r.rejectionReason}
                      </p>
                    )}
                  </TD>
                  <TD>{dateTime(r.requestedAt)}</TD>
                  <TD>
                    {r.status === 'pending' && (
                      <div className="flex justify-end gap-2">
                        <Button
                          variant="danger"
                          onClick={() => setRejecting(r)}
                        >
                          Reject
                        </Button>
                        <Button
                          variant="success"
                          disabled={busyId === r.id}
                          onClick={() => onApprove(r)}
                        >
                          {busyId === r.id ? '…' : 'Approve'}
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
        title="Reject reactivation"
        label="Reason (sent to the applicant)"
        confirmText="Reject request"
        onClose={() => setRejecting(null)}
        onConfirm={(reason) => rejectReactivation(rejecting!.id, reason)}
        onDone={() => {
          setRejecting(null);
          reload();
        }}
      />
    </>
  );
}
