import { useState } from 'react';
import { approveDriver, getDrivers, rejectDriver } from '../api/admin';
import { errorMessage } from '../api/client';
import type { DriverRow } from '../api/types';
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
  StatusBadge,
} from '../components/ui';
import { Pagination, TBody, TD, THead, TR, Table } from '../components/Table';

const FILTERS = [
  { value: '', label: 'All' },
  { value: 'under_review', label: 'Under review' },
  { value: 'approved', label: 'Approved' },
  { value: 'rejected', label: 'Rejected' },
  { value: 'not_submitted', label: 'Not submitted' },
];

export default function Drivers() {
  const [page, setPage] = useState(1);
  const [status, setStatus] = useState('');
  const { data, loading, error, reload } = useAsync(
    () => getDrivers(page, 20, status || undefined),
    [page, status],
  );

  const [detail, setDetail] = useState<DriverRow | null>(null);
  const [rejecting, setRejecting] = useState<DriverRow | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);

  const onApprove = async (d: DriverRow) => {
    setBusyId(d.id);
    setActionError(null);
    try {
      await approveDriver(d.id);
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
        title="Driver Verification"
        subtitle="Review applications, inspect documents, approve or reject"
        actions={
          <div className="flex gap-1 rounded-lg border border-slate-200 bg-white p-1">
            {FILTERS.map((f) => (
              <button
                key={f.value}
                onClick={() => {
                  setStatus(f.value);
                  setPage(1);
                }}
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
        {data && data.drivers.length === 0 && (
          <EmptyState message="No driver applications match this filter." />
        )}
        {data && data.drivers.length > 0 && (
          <>
            <Table>
              <THead
                cols={['Driver', 'Phone', 'Status', 'Docs', 'Vehicle', 'Applied', '']}
              />
              <TBody>
                {data.drivers.map((d) => (
                  <TR key={d.id}>
                    <TD>
                      <div className="flex items-center gap-3">
                        <Avatar
                          name={d.user.fullName}
                          photoUrl={d.user.profilePhotoUrl}
                        />
                        <span className="font-medium text-slate-900">
                          {d.user.fullName ?? '—'}
                        </span>
                      </div>
                    </TD>
                    <TD>{d.user.phoneNumber}</TD>
                    <TD>
                      <StatusBadge status={d.verificationStatus} />
                    </TD>
                    <TD>
                      <Badge tone={d.documents.length ? 'blue' : 'gray'}>
                        {d.documents.length} file(s)
                      </Badge>
                    </TD>
                    <TD>
                      {d.vehicles[0]
                        ? `${d.vehicles[0].make} ${d.vehicles[0].model}`
                        : '—'}
                    </TD>
                    <TD>{dateOnly(d.createdAt)}</TD>
                    <TD>
                      <div className="flex justify-end">
                        <Button
                          variant="secondary"
                          onClick={() => setDetail(d)}
                        >
                          Review
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

      {/* Detail / document review modal */}
      <Modal
        open={!!detail}
        onClose={() => setDetail(null)}
        title="Driver Application"
        wide
      >
        {detail && (
          <div className="space-y-5">
            <div className="flex items-center gap-4">
              <Avatar
                name={detail.user.fullName}
                photoUrl={detail.user.profilePhotoUrl}
                size={56}
              />
              <div className="flex-1">
                <p className="text-lg font-semibold text-slate-900">
                  {detail.user.fullName ?? '—'}
                </p>
                <p className="text-sm text-slate-500">
                  {detail.user.phoneNumber} · Applied{' '}
                  {dateOnly(detail.createdAt)}
                </p>
              </div>
              <StatusBadge status={detail.verificationStatus} />
            </div>

            {detail.rejectionReason && (
              <div className="rounded-lg border border-rose-200 bg-rose-50 px-3 py-2 text-sm text-rose-700">
                Previous rejection: {detail.rejectionReason}
              </div>
            )}

            {detail.vehicles.length > 0 && (
              <div>
                <h3 className="mb-2 text-sm font-semibold text-slate-700">
                  Vehicles
                </h3>
                <div className="flex flex-wrap gap-2">
                  {detail.vehicles.map((v, i) => (
                    <span
                      key={i}
                      className="rounded-lg border border-slate-200 bg-slate-50 px-3 py-1.5 text-sm text-slate-700"
                    >
                      {v.make} {v.model} · {v.plateNumber} · {v.vehicleType}
                    </span>
                  ))}
                </div>
              </div>
            )}

            <div>
              <h3 className="mb-2 text-sm font-semibold text-slate-700">
                Uploaded documents
              </h3>
              <DocGallery docs={detail.documents} />
            </div>

            <div className="flex justify-end gap-2 border-t border-slate-200 pt-4">
              <Button
                variant="danger"
                disabled={detail.verificationStatus === 'approved'}
                onClick={() => setRejecting(detail)}
              >
                Reject
              </Button>
              <Button
                variant="success"
                disabled={
                  detail.verificationStatus === 'approved' ||
                  busyId === detail.id
                }
                onClick={() => onApprove(detail)}
              >
                {busyId === detail.id ? 'Approving…' : 'Approve driver'}
              </Button>
            </div>
          </div>
        )}
      </Modal>

      <ReasonModal
        open={!!rejecting}
        title="Reject driver application"
        label="Reason (sent to the driver)"
        confirmText="Reject application"
        onClose={() => setRejecting(null)}
        onConfirm={(reason) => rejectDriver(rejecting!.id, reason)}
        onDone={() => {
          setRejecting(null);
          setDetail(null);
          reload();
        }}
      />
    </>
  );
}
