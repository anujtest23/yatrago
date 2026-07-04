import { useState } from 'react';
import { approveVehicle, getVehicles, rejectVehicle } from '../api/admin';
import { errorMessage } from '../api/client';
import type { VehicleRow } from '../api/types';
import { useAsync } from '../lib/useAsync';
import { dateOnly } from '../lib/format';
import { Avatar } from '../components/Avatar';
import { DocGallery } from '../components/DocViewer';
import { Modal } from '../components/Modal';
import { ReasonModal } from '../components/ReasonModal';
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

const FILTERS = [
  { value: '', label: 'All' },
  { value: 'active', label: 'Approved' },
  { value: 'inactive', label: 'Pending / Rejected' },
];

export default function Vehicles() {
  const [status, setStatus] = useState('');
  const { data, loading, error, reload } = useAsync(
    () => getVehicles(status || undefined),
    [status],
  );

  const [detail, setDetail] = useState<VehicleRow | null>(null);
  const [rejecting, setRejecting] = useState<VehicleRow | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);

  const onApprove = async (v: VehicleRow) => {
    setBusyId(v.id);
    setActionError(null);
    try {
      await approveVehicle(v.id);
      setDetail(null);
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
        title="Vehicles"
        subtitle="Approve vehicles before they can be used for rides"
        actions={
          <div className="flex gap-1 rounded-lg border border-slate-200 bg-white p-1">
            {FILTERS.map((f) => (
              <button
                key={f.value}
                onClick={() => setStatus(f.value)}
                className={`rounded-md px-3 py-1 text-sm font-medium transition ${
                  status === f.value
                    ? 'bg-slate-900 text-white'
                    : 'text-slate-600 hover:bg-slate-100'
                }`}
              >
                {f.label}
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
        {data && data.vehicles.length === 0 && (
          <EmptyState message="No vehicles match this filter." />
        )}
        {data && data.vehicles.length > 0 && (
          <Table>
            <THead
              cols={['Vehicle', 'Plate', 'Type', 'Owner', 'Status', 'Added', '']}
            />
            <TBody>
              {data.vehicles.map((v) => (
                <TR key={v.id}>
                  <TD>
                    <span className="font-medium text-slate-900">
                      {v.make} {v.model}
                    </span>
                  </TD>
                  <TD>{v.plateNumber}</TD>
                  <TD className="capitalize">{v.vehicleType}</TD>
                  <TD>
                    <div className="flex items-center gap-2">
                      <Avatar
                        name={v.driver?.user?.fullName}
                        photoUrl={v.driver?.user?.profilePhotoUrl}
                        size={28}
                      />
                      <span>{v.driver?.user?.fullName ?? '—'}</span>
                    </div>
                  </TD>
                  <TD>
                    {v.isActive ? (
                      <Badge tone="green">Approved</Badge>
                    ) : (
                      <Badge tone="amber">Not approved</Badge>
                    )}
                  </TD>
                  <TD>{dateOnly(v.createdAt)}</TD>
                  <TD>
                    <div className="flex justify-end">
                      <Button variant="secondary" onClick={() => setDetail(v)}>
                        Review
                      </Button>
                    </div>
                  </TD>
                </TR>
              ))}
            </TBody>
          </Table>
        )}
      </Card>

      <Modal
        open={!!detail}
        onClose={() => setDetail(null)}
        title="Vehicle Review"
        wide
      >
        {detail && (
          <div className="space-y-5">
            <div className="grid grid-cols-2 gap-3 text-sm sm:grid-cols-4">
              <Field label="Make / Model" value={`${detail.make} ${detail.model}`} />
              <Field label="Plate" value={detail.plateNumber} />
              <Field label="Type" value={detail.vehicleType} />
              <Field
                label="Owner"
                value={detail.driver?.user?.fullName ?? '—'}
              />
            </div>
            <div>
              <h3 className="mb-2 text-sm font-semibold text-slate-700">
                Vehicle documents
              </h3>
              <DocGallery docs={detail.documents ?? []} />
            </div>
            <div className="flex justify-end gap-2 border-t border-slate-200 pt-4">
              <Button variant="danger" onClick={() => setRejecting(detail)}>
                Reject
              </Button>
              <Button
                variant="success"
                disabled={detail.isActive || busyId === detail.id}
                onClick={() => onApprove(detail)}
              >
                {busyId === detail.id ? 'Approving…' : 'Approve vehicle'}
              </Button>
            </div>
          </div>
        )}
      </Modal>

      <ReasonModal
        open={!!rejecting}
        title="Reject vehicle"
        label="Reason (sent to the driver)"
        confirmText="Reject vehicle"
        onClose={() => setRejecting(null)}
        onConfirm={(reason) => rejectVehicle(rejecting!.id, reason)}
        onDone={() => {
          setRejecting(null);
          setDetail(null);
          reload();
        }}
      />
    </>
  );
}

function Field({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <p className="text-xs uppercase tracking-wide text-slate-400">{label}</p>
      <p className="mt-0.5 font-medium capitalize text-slate-800">{value}</p>
    </div>
  );
}
