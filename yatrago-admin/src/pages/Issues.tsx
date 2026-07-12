import { useState } from 'react';
import { getIssues, updateIssue } from '../api/admin';
import { errorMessage } from '../api/client';
import type { IssueReportRow } from '../api/types';
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

const FILTERS = ['open', 'investigating', 'resolved', 'dismissed', ''];

export default function Issues() {
  const [status, setStatus] = useState('open');
  const { data, loading, error, reload } = useAsync(
    () => getIssues(status || undefined),
    [status],
  );
  const [resolving, setResolving] = useState<IssueReportRow | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);

  const setStatusFor = async (i: IssueReportRow, next: string) => {
    setBusyId(i.id);
    setActionError(null);
    try {
      await updateIssue(i.id, { status: next });
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
        title="Issue Reports"
        subtitle="Ride-specific problems reported by users"
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
          <EmptyState message="No issue reports match this filter." />
        )}
        {data && data.length > 0 && (
          <Table>
            <THead cols={['User', 'Category', 'Description', 'Status', 'Created', '']} />
            <TBody>
              {data.map((i) => (
                <TR key={i.id}>
                  <TD>
                    <p className="font-medium text-slate-900">
                      {i.user?.fullName ?? '—'}
                    </p>
                    <p className="text-xs text-slate-400">
                      {i.user?.phoneNumber}
                    </p>
                  </TD>
                  <TD className="capitalize">{i.category}</TD>
                  <TD>
                    <p className="max-w-md truncate text-slate-900">
                      {i.description}
                    </p>
                    {i.resolution && (
                      <p className="mt-0.5 text-xs text-emerald-600">
                        {i.resolution}
                      </p>
                    )}
                  </TD>
                  <TD>
                    <StatusBadge status={i.status} />
                  </TD>
                  <TD>{dateTime(i.createdAt)}</TD>
                  <TD>
                    {i.status !== 'resolved' && i.status !== 'dismissed' && (
                      <div className="flex justify-end gap-2">
                        {i.status === 'open' && (
                          <Button
                            disabled={busyId === i.id}
                            onClick={() => setStatusFor(i, 'investigating')}
                          >
                            Investigate
                          </Button>
                        )}
                        <Button
                          disabled={busyId === i.id}
                          onClick={() => setStatusFor(i, 'dismissed')}
                        >
                          Dismiss
                        </Button>
                        <Button
                          variant="success"
                          onClick={() => setResolving(i)}
                        >
                          Resolve
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
        open={!!resolving}
        title="Resolve issue"
        label="Resolution notes (sent to the user)"
        confirmText="Mark resolved"
        onClose={() => setResolving(null)}
        onConfirm={(resolution) =>
          updateIssue(resolving!.id, { status: 'resolved', resolution })
        }
        onDone={() => {
          setResolving(null);
          reload();
        }}
      />
    </>
  );
}
