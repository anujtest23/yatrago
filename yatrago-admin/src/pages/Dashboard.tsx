import { Link } from 'react-router-dom';
import { getDashboard } from '../api/admin';
import { useAsync } from '../lib/useAsync';
import { npr } from '../lib/format';
import { Card, ErrorState, PageHeader, Spinner } from '../components/ui';

function Stat({
  label,
  value,
  hint,
  accent,
}: {
  label: string;
  value: string;
  hint?: string;
  accent: string;
}) {
  return (
    <Card className="p-5">
      <div className="flex items-start justify-between">
        <p className="text-sm font-medium text-slate-500">{label}</p>
        <span className={`h-2.5 w-2.5 rounded-full ${accent}`} />
      </div>
      <p className="mt-2 text-3xl font-semibold text-slate-900">{value}</p>
      {hint && <p className="mt-1 text-xs text-slate-400">{hint}</p>}
    </Card>
  );
}

export default function Dashboard() {
  const { data, loading, error } = useAsync(getDashboard, []);

  return (
    <>
      <PageHeader
        title="Dashboard"
        subtitle="Platform-wide key metrics at a glance"
      />

      {loading && <Spinner />}
      {error && <ErrorState message={error} />}

      {data && (
        <>
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
            <Stat
              label="Total Users"
              value={data.users.total.toLocaleString()}
              accent="bg-blue-500"
            />
            <Stat
              label="Drivers"
              value={data.drivers.total.toLocaleString()}
              hint={`${data.drivers.approved} approved · ${data.drivers.pendingApproval} pending`}
              accent="bg-violet-500"
            />
            <Stat
              label="Total Trips"
              value={data.trips.total.toLocaleString()}
              hint={`${data.trips.today} today`}
              accent="bg-emerald-500"
            />
            <Stat
              label="Revenue"
              value={npr(data.revenue.total)}
              hint={`${npr(data.revenue.today)} today`}
              accent="bg-amber-500"
            />
          </div>

          <h2 className="mb-3 mt-8 text-sm font-semibold uppercase tracking-wide text-slate-500">
            Bookings
          </h2>
          <div className="grid grid-cols-2 gap-4 xl:grid-cols-4">
            <Stat
              label="Total Bookings"
              value={data.bookings.total.toLocaleString()}
              accent="bg-slate-400"
            />
            <Stat
              label="Today"
              value={data.bookings.today.toLocaleString()}
              accent="bg-slate-400"
            />
            <Stat
              label="Pending"
              value={data.bookings.pending.toLocaleString()}
              accent="bg-amber-500"
            />
            <Stat
              label="Confirmed"
              value={data.bookings.confirmed.toLocaleString()}
              accent="bg-emerald-500"
            />
          </div>

          <h2 className="mb-3 mt-8 text-sm font-semibold uppercase tracking-wide text-slate-500">
            Quick actions
          </h2>
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-4">
            {[
              { to: '/drivers', label: 'Review driver verifications', badge: data.drivers.pendingApproval },
              { to: '/payouts', label: 'Process payouts' },
              { to: '/sos', label: 'Check SOS alerts' },
              { to: '/reports', label: 'Review reports' },
            ].map((a) => (
              <Link
                key={a.to}
                to={a.to}
                className="flex items-center justify-between rounded-xl border border-slate-200 bg-white px-4 py-3 text-sm font-medium text-slate-700 shadow-sm transition hover:border-slate-300 hover:bg-slate-50"
              >
                {a.label}
                {a.badge ? (
                  <span className="rounded-full bg-amber-100 px-2 py-0.5 text-xs font-semibold text-amber-700">
                    {a.badge}
                  </span>
                ) : (
                  <span className="text-slate-400">→</span>
                )}
              </Link>
            ))}
          </div>
        </>
      )}
    </>
  );
}
