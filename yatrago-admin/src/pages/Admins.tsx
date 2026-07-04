import { useState } from 'react';
import {
  addAdmin,
  getAdmins,
  revokeAdmin,
  updateAdminRole,
} from '../api/admin';
import { errorMessage } from '../api/client';
import type { AdminAccount } from '../api/types';
import { useAuth } from '../auth/AuthContext';
import { useAsync } from '../lib/useAsync';
import { dateOnly } from '../lib/format';
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
} from '../components/ui';
import { TBody, TD, THead, TR, Table } from '../components/Table';

function RoleBadge({ role }: { role: string }) {
  return role === 'super_admin' ? (
    <Badge tone="purple">Super admin</Badge>
  ) : (
    <Badge tone="blue">Admin</Badge>
  );
}

export default function Admins() {
  const { user } = useAuth();
  const { data, loading, error, reload } = useAsync(getAdmins, []);

  const [showAdd, setShowAdd] = useState(false);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);

  const act = async (fn: () => Promise<unknown>, id: string) => {
    setBusyId(id);
    setActionError(null);
    try {
      await fn();
      reload();
    } catch (err) {
      setActionError(errorMessage(err));
    } finally {
      setBusyId(null);
    }
  };

  const toggleRole = (a: AdminAccount) => {
    const next = a.role === 'super_admin' ? 'admin' : 'super_admin';
    if (
      !window.confirm(
        `Change ${a.fullName ?? a.phoneNumber} to ${next.replace('_', ' ')}?`,
      )
    )
      return;
    act(() => updateAdminRole(a.id, next), a.id);
  };

  const revoke = (a: AdminAccount) => {
    if (
      !window.confirm(
        `Revoke admin access for ${a.fullName ?? a.phoneNumber}? They revert to a normal user account.`,
      )
    )
      return;
    act(() => revokeAdmin(a.id), a.id);
  };

  return (
    <>
      <PageHeader
        title="Admins"
        subtitle="Manage who can access the console and their privilege level"
        actions={
          <Button onClick={() => setShowAdd(true)}>+ Add admin</Button>
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
        {data && data.admins.length === 0 && (
          <EmptyState message="No admins yet." />
        )}
        {data && data.admins.length > 0 && (
          <Table>
            <THead cols={['Admin', 'Phone', 'Role', 'Status', 'Since', '']} />
            <TBody>
              {data.admins.map((a) => {
                const isSelf = a.id === user?.id;
                return (
                  <TR key={a.id}>
                    <TD>
                      <div className="flex items-center gap-3">
                        <Avatar
                          name={a.fullName}
                          photoUrl={a.profilePhotoUrl}
                        />
                        <span className="font-medium text-slate-900">
                          {a.fullName ?? '—'}
                          {isSelf && (
                            <span className="ml-2 text-xs text-slate-400">
                              (you)
                            </span>
                          )}
                        </span>
                      </div>
                    </TD>
                    <TD>{a.phoneNumber}</TD>
                    <TD>
                      <RoleBadge role={a.role} />
                    </TD>
                    <TD>
                      {a.isActive ? (
                        <Badge tone="green">Active</Badge>
                      ) : (
                        <Badge tone="red">Blocked</Badge>
                      )}
                    </TD>
                    <TD>{dateOnly(a.createdAt)}</TD>
                    <TD>
                      <div className="flex justify-end gap-2">
                        <Button
                          variant="secondary"
                          disabled={isSelf || busyId === a.id}
                          onClick={() => toggleRole(a)}
                        >
                          {a.role === 'super_admin'
                            ? 'Make admin'
                            : 'Make super'}
                        </Button>
                        <Button
                          variant="danger"
                          disabled={isSelf || busyId === a.id}
                          onClick={() => revoke(a)}
                        >
                          {busyId === a.id ? '…' : 'Revoke'}
                        </Button>
                      </div>
                    </TD>
                  </TR>
                );
              })}
            </TBody>
          </Table>
        )}
      </Card>

      <AddAdminModal
        open={showAdd}
        onClose={() => setShowAdd(false)}
        onDone={() => {
          setShowAdd(false);
          reload();
        }}
      />
    </>
  );
}

function AddAdminModal({
  open,
  onClose,
  onDone,
}: {
  open: boolean;
  onClose: () => void;
  onDone: () => void;
}) {
  const [phone, setPhone] = useState('');
  const [role, setRole] = useState<'admin' | 'super_admin'>('admin');
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!phone.trim()) {
      setErr('Enter a phone number.');
      return;
    }
    setBusy(true);
    setErr(null);
    try {
      await addAdmin(phone.trim(), role);
      setPhone('');
      setRole('admin');
      onDone();
    } catch (e2) {
      setErr(errorMessage(e2));
    } finally {
      setBusy(false);
    }
  };

  return (
    <Modal open={open} onClose={onClose} title="Grant admin access">
      <form onSubmit={submit} className="space-y-4">
        {err && <ErrorState message={err} />}
        <p className="text-sm text-slate-500">
          The person must already have a YatraGo account (logged in once). Enter
          the phone number they use.
        </p>
        <div>
          <label className="mb-1 block text-sm font-medium text-slate-700">
            Phone number
          </label>
          <input
            autoFocus
            value={phone}
            onChange={(e) => setPhone(e.target.value)}
            placeholder="+9779812345678"
            className="w-full rounded-lg border border-slate-300 px-3 py-2 text-sm outline-none focus:border-slate-900"
          />
        </div>
        <div>
          <label className="mb-1 block text-sm font-medium text-slate-700">
            Role
          </label>
          <select
            value={role}
            onChange={(e) =>
              setRole(e.target.value as 'admin' | 'super_admin')
            }
            className="w-full rounded-lg border border-slate-300 px-3 py-2 text-sm outline-none focus:border-slate-900"
          >
            <option value="admin">Admin</option>
            <option value="super_admin">Super admin</option>
          </select>
        </div>
        <div className="flex justify-end gap-2">
          <Button type="button" variant="secondary" onClick={onClose}>
            Cancel
          </Button>
          <Button type="submit" disabled={busy}>
            {busy ? 'Granting…' : 'Grant access'}
          </Button>
        </div>
      </form>
    </Modal>
  );
}
