import { useState } from 'react';
import { getBookings } from '../api/admin';
import { useAsync } from '../lib/useAsync';
import { dateTime, npr } from '../lib/format';
import {
  Badge,
  Card,
  EmptyState,
  ErrorState,
  PageHeader,
  Spinner,
  StatusBadge,
} from '../components/ui';
import { Pagination, TBody, TD, THead, TR, Table } from '../components/Table';

const FILTERS = [
  '',
  'pending',
  'confirmed',
  'rejected',
  'cancelled',
  'completed',
];

export default function Bookings() {
  const [page, setPage] = useState(1);
  const [status, setStatus] = useState('');
  const { data, loading, error } = useAsync(
    () => getBookings(page, 20, status || undefined),
    [page, status],
  );

  return (
    <>
      <PageHeader
        title="Bookings"
        subtitle="Every seat request across the platform"
        actions={
          <div className="flex flex-wrap gap-1 rounded-lg border border-slate-200 bg-white p-1">
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
                {f || 'All'}
              </button>
            ))}
          </div>
        }
      />

      <Card>
        {loading && <Spinner />}
        {error && <ErrorState message={error} />}
        {data && data.bookings.length === 0 && (
          <EmptyState message="No bookings match this filter." />
        )}
        {data && data.bookings.length > 0 && (
          <>
            <Table>
              <THead
                cols={['Passenger', 'Route', 'Driver', 'Seats', 'Amount', 'Payment', 'Status', 'Booked']}
              />
              <TBody>
                {data.bookings.map((b) => (
                  <TR key={b.id}>
                    <TD>
                      <span className="font-medium text-slate-900">
                        {b.passenger?.fullName ?? '—'}
                      </span>
                      <p className="text-xs text-slate-400">
                        {b.passenger?.phoneNumber}
                      </p>
                    </TD>
                    <TD>
                      {b.ride
                        ? `${b.ride.originName} → ${b.ride.destName}`
                        : '—'}
                    </TD>
                    <TD>{b.ride?.driver?.user?.fullName ?? '—'}</TD>
                    <TD>{b.seatsBooked}</TD>
                    <TD>{npr(b.totalAmount)}</TD>
                    <TD>
                      <Badge
                        tone={b.paymentStatus === 'paid' ? 'green' : 'gray'}
                      >
                        {b.paymentStatus}
                      </Badge>
                    </TD>
                    <TD>
                      <StatusBadge status={b.status} />
                    </TD>
                    <TD>{dateTime(b.bookedAt)}</TD>
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
    </>
  );
}
