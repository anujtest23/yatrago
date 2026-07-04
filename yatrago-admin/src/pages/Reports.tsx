import { useState } from 'react';
import {
  getReports,
  hideRating,
  unhideRating,
  updateReportStatus,
} from '../api/admin';
import { errorMessage } from '../api/client';
import type { ReportRow } from '../api/types';
import { useAsync } from '../lib/useAsync';
import { dateTime } from '../lib/format';
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
// Actions the API accepts for a report (see UpdateReportStatusDto).
const ACTIONS = ['investigating', 'resolved', 'dismissed'];

export default function Reports() {
  const [status, setStatus] = useState('open');
  const { data, loading, error, reload } = useAsync(
    () => getReports(status || undefined),
    [status],
  );

  const [busyId, setBusyId] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);

  const setReportStatus = async (r: ReportRow, next: string) => {
    setBusyId(r.id);
    setActionError(null);
    try {
      await updateReportStatus(r.id, next);
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
        title="Reports"
        subtitle="User-submitted incident reports"
        actions={
          <div className="flex flex-wrap gap-1 rounded-lg border border-slate-200 bg-white p-1">
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

      <Card className="mb-6">
        {loading && <Spinner />}
        {error && <ErrorState message={error} />}
        {data && data.reports.length === 0 && (
          <EmptyState message="No reports match this filter." />
        )}
        {data && data.reports.length > 0 && (
          <Table>
            <THead
              cols={['Reporter', 'Reported', 'Reason', 'Trip', 'Status', 'Filed', 'Action']}
            />
            <TBody>
              {data.reports.map((r) => (
                <TR key={r.id}>
                  <TD>
                    <p className="font-medium text-slate-900">
                      {r.reporter?.fullName ?? '—'}
                    </p>
                    <p className="text-xs text-slate-400">
                      {r.reporter?.phoneNumber}
                    </p>
                  </TD>
                  <TD>
                    <p className="font-medium text-slate-900">
                      {r.reported?.fullName ?? '—'}
                    </p>
                    <p className="text-xs text-slate-400">
                      {r.reported?.phoneNumber}
                    </p>
                  </TD>
                  <TD>
                    <p className="max-w-xs">
                      <span className="font-medium capitalize">{r.reason}</span>
                      {r.description && (
                        <span className="block text-xs text-slate-500">
                          {r.description}
                        </span>
                      )}
                    </p>
                  </TD>
                  <TD>
                    {r.booking?.ride
                      ? `${r.booking.ride.originName} → ${r.booking.ride.destName}`
                      : '—'}
                  </TD>
                  <TD>
                    <StatusBadge status={r.status} />
                  </TD>
                  <TD>{dateTime(r.createdAt)}</TD>
                  <TD>
                    <select
                      disabled={busyId === r.id}
                      value=""
                      onChange={(e) =>
                        e.target.value && setReportStatus(r, e.target.value)
                      }
                      className="rounded-lg border border-slate-300 px-2 py-1 text-sm outline-none focus:border-slate-900"
                    >
                      <option value="">Set status…</option>
                      {ACTIONS.map((a) => (
                        <option key={a} value={a} className="capitalize">
                          {a}
                        </option>
                      ))}
                    </select>
                  </TD>
                </TR>
              ))}
            </TBody>
          </Table>
        )}
      </Card>

      <RatingModeration />
    </>
  );
}

// The API has no rating-list endpoint, only hide/unhide by id. This small
// utility lets an admin moderate a specific rating (id taken from a report or
// the app) without dropping to Postman.
function RatingModeration() {
  const [ratingId, setRatingId] = useState('');
  const [reason, setReason] = useState('');
  const [busy, setBusy] = useState<'hide' | 'unhide' | null>(null);
  const [msg, setMsg] = useState<string | null>(null);
  const [err, setErr] = useState<string | null>(null);

  const run = async (kind: 'hide' | 'unhide') => {
    if (!ratingId.trim()) {
      setErr('Enter a rating ID.');
      return;
    }
    if (kind === 'hide' && !reason.trim()) {
      setErr('A reason is required to hide a rating.');
      return;
    }
    setBusy(kind);
    setErr(null);
    setMsg(null);
    try {
      if (kind === 'hide') await hideRating(ratingId.trim(), reason.trim());
      else await unhideRating(ratingId.trim());
      setMsg(`Rating ${kind === 'hide' ? 'hidden' : 'unhidden'} successfully.`);
      setRatingId('');
      setReason('');
    } catch (e) {
      setErr(errorMessage(e));
    } finally {
      setBusy(null);
    }
  };

  return (
    <Card className="p-5">
      <h2 className="text-sm font-semibold text-slate-700">
        Rating moderation
      </h2>
      <p className="mt-1 text-xs text-slate-400">
        Hide or unhide a specific rating by its ID. Hidden ratings are excluded
        from averages and listings.
      </p>
      {err && (
        <div className="mt-3">
          <ErrorState message={err} />
        </div>
      )}
      {msg && (
        <div className="mt-3 rounded-lg border border-emerald-200 bg-emerald-50 px-3 py-2 text-sm text-emerald-700">
          {msg}
        </div>
      )}
      <div className="mt-4 flex flex-wrap items-end gap-3">
        <div className="flex-1">
          <label className="mb-1 block text-xs font-medium text-slate-600">
            Rating ID
          </label>
          <input
            value={ratingId}
            onChange={(e) => setRatingId(e.target.value)}
            placeholder="rating uuid"
            className="w-full rounded-lg border border-slate-300 px-3 py-2 text-sm outline-none focus:border-slate-900"
          />
        </div>
        <div className="flex-1">
          <label className="mb-1 block text-xs font-medium text-slate-600">
            Reason (to hide)
          </label>
          <input
            value={reason}
            onChange={(e) => setReason(e.target.value)}
            placeholder="e.g. abusive language"
            className="w-full rounded-lg border border-slate-300 px-3 py-2 text-sm outline-none focus:border-slate-900"
          />
        </div>
        <div className="flex gap-2">
          <Button
            variant="danger"
            disabled={busy !== null}
            onClick={() => run('hide')}
          >
            {busy === 'hide' ? '…' : 'Hide'}
          </Button>
          <Button
            variant="secondary"
            disabled={busy !== null}
            onClick={() => run('unhide')}
          >
            {busy === 'unhide' ? '…' : 'Unhide'}
          </Button>
        </div>
      </div>
    </Card>
  );
}
