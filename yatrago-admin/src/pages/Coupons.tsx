import { useState } from 'react';
import { createCoupon, deactivateCoupon, getCoupons } from '../api/admin';
import { errorMessage } from '../api/client';
import type { CouponRow } from '../api/types';
import { useAsync } from '../lib/useAsync';
import { dateTime, npr } from '../lib/format';
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

const inputCls =
  'w-full rounded-md border border-slate-200 px-3 py-1.5 text-sm focus:border-slate-400 focus:outline-none';

const EMPTY = {
  code: '',
  discountType: 'percentage',
  discountValue: '',
  maxDiscount: '',
  minAmount: '',
  audience: 'all',
  usageLimit: '',
  perUserLimit: '',
  validUntil: '',
};

export default function Coupons() {
  const { data, loading, error, reload } = useAsync(() => getCoupons(), []);
  const [form, setForm] = useState({ ...EMPTY });
  const [showForm, setShowForm] = useState(false);
  const [busy, setBusy] = useState(false);
  const [actionError, setActionError] = useState<string | null>(null);

  const set = (k: keyof typeof EMPTY, v: string) =>
    setForm((f) => ({ ...f, [k]: v }));

  const num = (v: string) => (v === '' ? undefined : Number(v));

  const submit = async () => {
    setBusy(true);
    setActionError(null);
    try {
      await createCoupon({
        code: form.code.trim(),
        discountType: form.discountType as CouponRow['discountType'],
        discountValue: Number(form.discountValue),
        maxDiscount: num(form.maxDiscount),
        minAmount: num(form.minAmount) ?? 0,
        audience: form.audience as CouponRow['audience'],
        usageLimit: num(form.usageLimit),
        perUserLimit: num(form.perUserLimit),
        validUntil: form.validUntil
          ? new Date(form.validUntil).toISOString()
          : null,
      });
      setForm({ ...EMPTY });
      setShowForm(false);
      reload();
    } catch (err) {
      setActionError(errorMessage(err));
    } finally {
      setBusy(false);
    }
  };

  const disable = async (c: CouponRow) => {
    if (!window.confirm(`Deactivate coupon ${c.code}?`)) return;
    setActionError(null);
    try {
      await deactivateCoupon(c.id);
      reload();
    } catch (err) {
      setActionError(errorMessage(err));
    }
  };

  return (
    <>
      <PageHeader
        title="Coupons"
        subtitle="Create and manage discount codes"
        actions={
          <Button onClick={() => setShowForm((s) => !s)}>
            {showForm ? 'Cancel' : 'New coupon'}
          </Button>
        }
      />

      {actionError && (
        <div className="mb-4">
          <ErrorState message={actionError} />
        </div>
      )}

      {showForm && (
        <Card>
          <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
            <label className="text-xs font-medium text-slate-600">
              Code
              <input
                className={inputCls}
                value={form.code}
                onChange={(e) => set('code', e.target.value)}
              />
            </label>
            <label className="text-xs font-medium text-slate-600">
              Type
              <select
                className={inputCls}
                value={form.discountType}
                onChange={(e) => set('discountType', e.target.value)}
              >
                <option value="percentage">percentage</option>
                <option value="fixed">fixed</option>
              </select>
            </label>
            <label className="text-xs font-medium text-slate-600">
              Value ({form.discountType === 'percentage' ? '%' : 'NPR'})
              <input
                className={inputCls}
                type="number"
                value={form.discountValue}
                onChange={(e) => set('discountValue', e.target.value)}
              />
            </label>
            <label className="text-xs font-medium text-slate-600">
              Max discount (NPR)
              <input
                className={inputCls}
                type="number"
                value={form.maxDiscount}
                onChange={(e) => set('maxDiscount', e.target.value)}
              />
            </label>
            <label className="text-xs font-medium text-slate-600">
              Min amount (NPR)
              <input
                className={inputCls}
                type="number"
                value={form.minAmount}
                onChange={(e) => set('minAmount', e.target.value)}
              />
            </label>
            <label className="text-xs font-medium text-slate-600">
              Audience
              <select
                className={inputCls}
                value={form.audience}
                onChange={(e) => set('audience', e.target.value)}
              >
                <option value="all">all</option>
                <option value="passenger">passenger</option>
                <option value="driver">driver</option>
              </select>
            </label>
            <label className="text-xs font-medium text-slate-600">
              Usage limit
              <input
                className={inputCls}
                type="number"
                value={form.usageLimit}
                onChange={(e) => set('usageLimit', e.target.value)}
              />
            </label>
            <label className="text-xs font-medium text-slate-600">
              Per-user limit
              <input
                className={inputCls}
                type="number"
                value={form.perUserLimit}
                onChange={(e) => set('perUserLimit', e.target.value)}
              />
            </label>
            <label className="text-xs font-medium text-slate-600">
              Valid until
              <input
                className={inputCls}
                type="date"
                value={form.validUntil}
                onChange={(e) => set('validUntil', e.target.value)}
              />
            </label>
          </div>
          <div className="mt-4 flex justify-end">
            <Button
              variant="success"
              disabled={busy || !form.code || !form.discountValue}
              onClick={submit}
            >
              {busy ? 'Creating…' : 'Create coupon'}
            </Button>
          </div>
        </Card>
      )}

      <div className="mt-4">
        <Card>
          {loading && <Spinner />}
          {error && <ErrorState message={error} />}
          {data && data.length === 0 && (
            <EmptyState message="No coupons yet." />
          )}
          {data && data.length > 0 && (
            <Table>
              <THead
                cols={['Code', 'Discount', 'Min', 'Audience', 'Limits', 'Status', 'Expires', '']}
              />
              <TBody>
                {data.map((c) => (
                  <TR key={c.id}>
                    <TD className="font-mono font-medium text-slate-900">
                      {c.code}
                    </TD>
                    <TD>
                      {c.discountType === 'percentage'
                        ? `${c.discountValue}%${c.maxDiscount ? ` (max ${npr(c.maxDiscount)})` : ''}`
                        : npr(c.discountValue)}
                    </TD>
                    <TD>{c.minAmount ? npr(c.minAmount) : '—'}</TD>
                    <TD className="capitalize">{c.audience}</TD>
                    <TD className="text-xs text-slate-500">
                      {c.usageLimit ? `total ${c.usageLimit}` : '∞'}
                      {c.perUserLimit ? ` · ${c.perUserLimit}/user` : ''}
                    </TD>
                    <TD>
                      <StatusBadge status={c.isActive ? 'active' : 'inactive'} />
                    </TD>
                    <TD>{c.validUntil ? dateTime(c.validUntil) : '—'}</TD>
                    <TD>
                      {c.isActive && (
                        <div className="flex justify-end">
                          <Button variant="danger" onClick={() => disable(c)}>
                            Deactivate
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
      </div>
    </>
  );
}
