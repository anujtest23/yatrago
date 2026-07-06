import { useState } from 'react';
import {
  approveTopUpRequest,
  getTopUpRequests,
  rejectTopUpRequest,
  type TopUpRequestRow,
} from '../api/admin';
import { errorMessage } from '../api/client';
import { useAsync } from '../lib/useAsync';
import { dateTime, npr } from '../lib/format';
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

export default function TopUps() {
  const [status, setStatus] = useState('pending');
  const { data, loading, error, reload } = useAsync(
    () => getTopUpRequests(status || undefined),
    [status],
  );

  const [rejecting, setRejecting] = useState<TopUpRequestRow | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);

  const onApprove = async (r: TopUpRequestRow) => {
    if (
      !window.confirm(
        `Credit ${npr(r.amount)} to ${r.user.fullName ?? r.user.phoneNumber}? ` +
          'Confirm the off-app payment was received first.',
      )
    )
      return;
    setBusyId(r.id);
    setActionError(null);
    try {
      await approveTopUpRequest(r.id);
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
        title="Wallet Top-Ups"
        subtitle="Verify off-app payments before crediting user wallets"
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
        {data && data.requests.length === 0 && (
          <EmptyState message="No top-up requests match this filter." />
        )}
        {data && data.requests.length > 0 && (
          <Table>
            <THead
              cols={['User', 'Amount', 'Reference', 'Status', 'Requested', '']}
            />
            <TBody>
              {data.requests.map((r) => (
                <TR key={r.id}>
                  <TD>
                    <p className="font-medium text-slate-900">
                      {r.user.fullName ?? '—'}
                    </p>
                    <p className="text-xs text-slate-400">
                      {r.user.phoneNumber}
                    </p>
                  </TD>
                  <TD className="font-medium">{npr(r.amount)}</TD>
                  <TD className="text-sm text-slate-500">
                    {r.reference || '—'}
                  </TD>
                  <TD>
                    <StatusBadge status={r.status} />
                    {r.adminNote && (
                      <p className="mt-0.5 text-xs text-rose-500">
                        {r.adminNote}
                      </p>
                    )}
                  </TD>
                  <TD>{dateTime(r.createdAt)}</TD>
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
                          {busyId === r.id ? '…' : 'Approve & Credit'}
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
        title="Reject top-up request"
        label="Reason shown to the requester"
        confirmText="Reject"
        onClose={() => setRejecting(null)}
        onConfirm={(reason) => rejectTopUpRequest(rejecting!.id, reason)}
        onDone={() => {
          setRejecting(null);
          reload();
        }}
      />
    </>
  );
}
