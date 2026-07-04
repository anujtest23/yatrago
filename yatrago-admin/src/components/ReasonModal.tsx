import { useState } from 'react';
import { Modal } from './Modal';
import { Button, ErrorState } from './ui';
import { errorMessage } from '../api/client';

// Generic "give a reason, then confirm" dialog reused by reject/cancel flows.
export function ReasonModal({
  open,
  title,
  label = 'Reason',
  confirmText = 'Confirm',
  confirmVariant = 'danger',
  onClose,
  onConfirm,
  onDone,
}: {
  open: boolean;
  title: string;
  label?: string;
  confirmText?: string;
  confirmVariant?: 'danger' | 'primary' | 'success';
  onClose: () => void;
  onConfirm: (reason: string) => Promise<unknown>;
  onDone: () => void;
}) {
  const [reason, setReason] = useState('');
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!reason.trim()) {
      setErr('A reason is required.');
      return;
    }
    setBusy(true);
    setErr(null);
    try {
      await onConfirm(reason.trim());
      setReason('');
      onDone();
    } catch (e2) {
      setErr(errorMessage(e2));
    } finally {
      setBusy(false);
    }
  };

  return (
    <Modal open={open} onClose={onClose} title={title}>
      <form onSubmit={submit} className="space-y-4">
        {err && <ErrorState message={err} />}
        <div>
          <label className="mb-1 block text-sm font-medium text-slate-700">
            {label}
          </label>
          <textarea
            autoFocus
            rows={3}
            value={reason}
            onChange={(e) => setReason(e.target.value)}
            className="w-full rounded-lg border border-slate-300 px-3 py-2 text-sm outline-none focus:border-slate-900"
          />
        </div>
        <div className="flex justify-end gap-2">
          <Button type="button" variant="secondary" onClick={onClose}>
            Cancel
          </Button>
          <Button type="submit" variant={confirmVariant} disabled={busy}>
            {busy ? 'Working…' : confirmText}
          </Button>
        </div>
      </form>
    </Modal>
  );
}
