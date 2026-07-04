import { useState } from 'react';
import { blockUser, creditWallet, getUsers } from '../api/admin';
import { errorMessage } from '../api/client';
import type { UserRow } from '../api/types';
import { useAsync } from '../lib/useAsync';
import { dateOnly, npr } from '../lib/format';
import { Avatar } from '../components/Avatar';
import { Modal } from '../components/Modal';
import {
  Badge,
  Button,
  Card,
  EmptyState,
  ErrorState,
  PageHeader,
  Spinner,
  StatusBadge,
} from '../components/ui';
import { Pagination, TBody, TD, THead, TR, Table } from '../components/Table';

export default function Users() {
  const [page, setPage] = useState(1);
  const [searchInput, setSearchInput] = useState('');
  const [search, setSearch] = useState('');
  const { data, loading, error, reload } = useAsync(
    () => getUsers(page, 20, search || undefined),
    [page, search],
  );

  const [creditFor, setCreditFor] = useState<UserRow | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);

  const onSearch = (e: React.FormEvent) => {
    e.preventDefault();
    setPage(1);
    setSearch(searchInput.trim());
  };

  const onBlock = async (u: UserRow) => {
    if (!u.isActive) return;
    if (
      !window.confirm(
        `Block ${u.fullName ?? u.phoneNumber}? This cancels their active bookings/rides and forces logout.`,
      )
    )
      return;
    setBusyId(u.id);
    setActionError(null);
    try {
      await blockUser(u.id);
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
        title="Users"
        subtitle="Manage every account on the platform"
        actions={
          <form onSubmit={onSearch} className="flex gap-2">
            <input
              value={searchInput}
              onChange={(e) => setSearchInput(e.target.value)}
              placeholder="Search name or phone"
              className="w-56 rounded-lg border border-slate-300 px-3 py-1.5 text-sm outline-none focus:border-slate-900"
            />
            <Button type="submit" variant="secondary">
              Search
            </Button>
          </form>
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
        {data && data.users.length === 0 && (
          <EmptyState message="No users found." />
        )}
        {data && data.users.length > 0 && (
          <>
            <Table>
              <THead
                cols={['User', 'Phone', 'Role', 'Status', 'Bookings', 'Joined', '']}
              />
              <TBody>
                {data.users.map((u) => (
                  <TR key={u.id}>
                    <TD>
                      <div className="flex items-center gap-3">
                        <Avatar name={u.fullName} photoUrl={u.profilePhotoUrl} />
                        <div>
                          <p className="font-medium text-slate-900">
                            {u.fullName ?? '—'}
                          </p>
                          {u.driverProfile && (
                            <p className="text-xs text-slate-400">
                              ★ {u.driverProfile.averageRating ?? 0} ·{' '}
                              {u.driverProfile.totalTrips} trips
                            </p>
                          )}
                        </div>
                      </div>
                    </TD>
                    <TD>{u.phoneNumber}</TD>
                    <TD>
                      {u.driverProfile ? (
                        <div className="flex flex-col gap-1">
                          <Badge tone="violet">Driver</Badge>
                          <StatusBadge
                            status={u.driverProfile.verificationStatus}
                          />
                        </div>
                      ) : (
                        <Badge tone="blue">Passenger</Badge>
                      )}
                    </TD>
                    <TD>
                      {u.isActive ? (
                        <Badge tone="green">Active</Badge>
                      ) : (
                        <Badge tone="red">Blocked</Badge>
                      )}
                    </TD>
                    <TD>{u._count?.bookings ?? 0}</TD>
                    <TD>{dateOnly(u.createdAt)}</TD>
                    <TD>
                      <div className="flex justify-end gap-2">
                        <Button
                          variant="secondary"
                          onClick={() => setCreditFor(u)}
                        >
                          Credit wallet
                        </Button>
                        <Button
                          variant="danger"
                          disabled={!u.isActive || busyId === u.id}
                          onClick={() => onBlock(u)}
                        >
                          {busyId === u.id ? '…' : 'Block'}
                        </Button>
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

      <CreditWalletModal
        user={creditFor}
        onClose={() => setCreditFor(null)}
        onDone={() => {
          setCreditFor(null);
          reload();
        }}
      />
    </>
  );
}

function CreditWalletModal({
  user,
  onClose,
  onDone,
}: {
  user: UserRow | null;
  onClose: () => void;
  onDone: () => void;
}) {
  const [amount, setAmount] = useState('');
  const [note, setNote] = useState('');
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!user) return;
    const value = Number(amount);
    if (!value || value <= 0) {
      setErr('Enter a positive amount.');
      return;
    }
    setBusy(true);
    setErr(null);
    try {
      await creditWallet(user.id, value, note.trim() || undefined);
      setAmount('');
      setNote('');
      onDone();
    } catch (e2) {
      setErr(errorMessage(e2));
    } finally {
      setBusy(false);
    }
  };

  return (
    <Modal
      open={!!user}
      onClose={onClose}
      title={`Credit wallet — ${user?.fullName ?? user?.phoneNumber ?? ''}`}
    >
      <form onSubmit={submit} className="space-y-4">
        {err && <ErrorState message={err} />}
        <p className="text-sm text-slate-500">
          Adds funds to this user's wallet. Backend supports credit only —
          deductions are not available via API.
        </p>
        <div>
          <label className="mb-1 block text-sm font-medium text-slate-700">
            Amount ({npr(0).split(' ')[0]})
          </label>
          <input
            type="number"
            min="1"
            autoFocus
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            className="w-full rounded-lg border border-slate-300 px-3 py-2 text-sm outline-none focus:border-slate-900"
          />
        </div>
        <div>
          <label className="mb-1 block text-sm font-medium text-slate-700">
            Note (optional)
          </label>
          <input
            value={note}
            onChange={(e) => setNote(e.target.value)}
            placeholder="Reason for the credit"
            className="w-full rounded-lg border border-slate-300 px-3 py-2 text-sm outline-none focus:border-slate-900"
          />
        </div>
        <div className="flex justify-end gap-2">
          <Button type="button" variant="secondary" onClick={onClose}>
            Cancel
          </Button>
          <Button type="submit" variant="success" disabled={busy}>
            {busy ? 'Crediting…' : 'Credit wallet'}
          </Button>
        </div>
      </form>
    </Modal>
  );
}
