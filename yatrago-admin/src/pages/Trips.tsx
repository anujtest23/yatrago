import { useState } from 'react';
import { forceCancelRide, getTrips, overrideRidePrice } from '../api/admin';
import { errorMessage } from '../api/client';
import type { TripRow } from '../api/types';
import { useAsync } from '../lib/useAsync';
import { dateTime, npr } from '../lib/format';
import { Modal } from '../components/Modal';
import {
  Button,
  Card,
  EmptyState,
  ErrorState,
  PageHeader,
  Spinner,
  StatusBadge,
} from '../components/ui';
import { Pagination, TBody, TD, THead, TR, Table } from '../components/Table';

const FILTERS = ['', 'published', 'in_progress', 'completed', 'cancelled'];

export default function Trips() {
  const [page, setPage] = useState(1);
  const [status, setStatus] = useState('');
  const { data, loading, error, reload } = useAsync(
    () => getTrips(page, 20, status || undefined),
    [page, status],
  );

  const [priceFor, setPriceFor] = useState<TripRow | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);

  const onCancel = async (t: TripRow) => {
    if (
      !window.confirm(
        `Force-cancel this ride? All active bookings will be cancelled and paid passengers refunded.`,
      )
    )
      return;
    setBusyId(t.id);
    setActionError(null);
    try {
      await forceCancelRide(t.id);
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
        title="Trips"
        subtitle="Monitor rides and intervene when needed"
        actions={
          <div className="flex gap-1 rounded-lg border border-slate-200 bg-white p-1">
            {FILTERS.map((f) => (
              <button
                key={f || 'all'}
                onClick={() => {
                  setStatus(f);
                  setPage(1);
                }}
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
        {data && data.trips.length === 0 && (
          <EmptyState message="No trips match this filter." />
        )}
        {data && data.trips.length > 0 && (
          <>
            <Table>
              <THead
                cols={['Route', 'Driver', 'Departure', 'Price', 'Seats', 'Bookings', 'Status', '']}
              />
              <TBody>
                {data.trips.map((t) => (
                  <TR key={t.id}>
                    <TD>
                      <span className="font-medium text-slate-900">
                        {t.originName} → {t.destName}
                      </span>
                    </TD>
                    <TD>{t.driver?.user?.fullName ?? '—'}</TD>
                    <TD>{dateTime(t.departureAt)}</TD>
                    <TD>{npr(t.pricePerSeat)}</TD>
                    <TD>{t.availableSeats}</TD>
                    <TD>{t._count?.bookings ?? 0}</TD>
                    <TD>
                      <StatusBadge status={t.status} />
                    </TD>
                    <TD>
                      <div className="flex justify-end gap-2">
                        {t.status === 'published' && (
                          <Button
                            variant="secondary"
                            onClick={() => setPriceFor(t)}
                          >
                            Price
                          </Button>
                        )}
                        {(t.status === 'published' ||
                          t.status === 'in_progress') && (
                          <Button
                            variant="danger"
                            disabled={busyId === t.id}
                            onClick={() => onCancel(t)}
                          >
                            {busyId === t.id ? '…' : 'Cancel'}
                          </Button>
                        )}
                      </div>
                    </TD>
                  </TR>
                ))}
              </TBody>
            </Table>
            <Pagination
              page={data.pagination.page}
              totalPages={data.pagination.totalPages}
              total={data.pagination.total}
              onChange={setPage}
            />
          </>
        )}
      </Card>

      <PriceModal
        trip={priceFor}
        onClose={() => setPriceFor(null)}
        onDone={() => {
          setPriceFor(null);
          reload();
        }}
      />
    </>
  );
}

function PriceModal({
  trip,
  onClose,
  onDone,
}: {
  trip: TripRow | null;
  onClose: () => void;
  onDone: () => void;
}) {
  const [price, setPrice] = useState('');
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!trip) return;
    const value = Number(price);
    if (!value || value <= 0) {
      setErr('Enter a valid price.');
      return;
    }
    setBusy(true);
    setErr(null);
    try {
      await overrideRidePrice(trip.id, value);
      setPrice('');
      onDone();
    } catch (e2) {
      setErr(errorMessage(e2));
    } finally {
      setBusy(false);
    }
  };

  return (
    <Modal
      open={!!trip}
      onClose={onClose}
      title="Override per-seat price"
    >
      <form onSubmit={submit} className="space-y-4">
        {err && <ErrorState message={err} />}
        <p className="text-sm text-slate-500">
          Current price: {npr(trip?.pricePerSeat)}. New price applies to future
          bookings only and must stay within the per-km cap.
        </p>
        <div>
          <label className="mb-1 block text-sm font-medium text-slate-700">
            New price per seat (NPR)
          </label>
          <input
            type="number"
            min="1"
            autoFocus
            value={price}
            onChange={(e) => setPrice(e.target.value)}
            className="w-full rounded-lg border border-slate-300 px-3 py-2 text-sm outline-none focus:border-slate-900"
          />
        </div>
        <div className="flex justify-end gap-2">
          <Button type="button" variant="secondary" onClick={onClose}>
            Cancel
          </Button>
          <Button type="submit" disabled={busy}>
            {busy ? 'Saving…' : 'Update price'}
          </Button>
        </div>
      </form>
    </Modal>
  );
}
