import type { ButtonHTMLAttributes, ReactNode } from 'react';

// ── Badge ──────────────────────────────────────────────────────
const BADGE_TONES: Record<string, string> = {
  green: 'bg-emerald-100 text-emerald-700',
  red: 'bg-rose-100 text-rose-700',
  amber: 'bg-amber-100 text-amber-700',
  blue: 'bg-blue-100 text-blue-700',
  gray: 'bg-slate-100 text-slate-600',
  purple: 'bg-violet-100 text-violet-700',
};

// Map a status string to a colour tone so every table reads consistently.
export function statusTone(status?: string): string {
  switch (status) {
    case 'approved':
    case 'completed':
    case 'confirmed':
    case 'resolved':
    case 'active':
    case 'paid':
      return 'green';
    case 'rejected':
    case 'failed':
    case 'cancelled':
    case 'open':
    case 'inactive':
      return 'red';
    case 'pending':
    case 'under_review':
    case 'investigating':
    case 'acknowledged':
    case 'in_progress':
      return 'amber';
    case 'published':
      return 'blue';
    case 'dismissed':
    case 'not_submitted':
      return 'gray';
    default:
      return 'gray';
  }
}

export function Badge({
  children,
  tone = 'gray',
}: {
  children: ReactNode;
  tone?: string;
}) {
  return (
    <span
      className={`inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium capitalize ${
        BADGE_TONES[tone] ?? BADGE_TONES.gray
      }`}
    >
      {children}
    </span>
  );
}

export function StatusBadge({ status }: { status?: string }) {
  return (
    <Badge tone={statusTone(status)}>{(status ?? '—').replace(/_/g, ' ')}</Badge>
  );
}

// ── Button ─────────────────────────────────────────────────────
type Variant = 'primary' | 'secondary' | 'danger' | 'success' | 'ghost';
const VARIANTS: Record<Variant, string> = {
  primary: 'bg-slate-900 text-white hover:bg-slate-700',
  secondary: 'bg-white text-slate-700 border border-slate-300 hover:bg-slate-50',
  danger: 'bg-rose-600 text-white hover:bg-rose-500',
  success: 'bg-emerald-600 text-white hover:bg-emerald-500',
  ghost: 'text-slate-600 hover:bg-slate-100',
};

export function Button({
  variant = 'primary',
  className = '',
  children,
  ...props
}: ButtonHTMLAttributes<HTMLButtonElement> & { variant?: Variant }) {
  return (
    <button
      className={`inline-flex items-center justify-center gap-1.5 rounded-lg px-3 py-1.5 text-sm font-medium transition disabled:cursor-not-allowed disabled:opacity-50 ${VARIANTS[variant]} ${className}`}
      {...props}
    >
      {children}
    </button>
  );
}

// ── Card ───────────────────────────────────────────────────────
export function Card({
  children,
  className = '',
}: {
  children: ReactNode;
  className?: string;
}) {
  return (
    <div
      className={`rounded-xl border border-slate-200 bg-white shadow-sm ${className}`}
    >
      {children}
    </div>
  );
}

// ── Page header ────────────────────────────────────────────────
export function PageHeader({
  title,
  subtitle,
  actions,
}: {
  title: string;
  subtitle?: string;
  actions?: ReactNode;
}) {
  return (
    <div className="mb-6 flex flex-wrap items-end justify-between gap-3">
      <div>
        <h1 className="text-2xl font-semibold text-slate-900">{title}</h1>
        {subtitle && <p className="mt-1 text-sm text-slate-500">{subtitle}</p>}
      </div>
      {actions && <div className="flex items-center gap-2">{actions}</div>}
    </div>
  );
}

// ── States ─────────────────────────────────────────────────────
export function Spinner() {
  return (
    <div className="flex items-center justify-center py-16">
      <div className="h-8 w-8 animate-spin rounded-full border-2 border-slate-300 border-t-slate-900" />
    </div>
  );
}

export function EmptyState({ message }: { message: string }) {
  return (
    <div className="py-16 text-center text-sm text-slate-400">{message}</div>
  );
}

export function ErrorState({ message }: { message: string }) {
  return (
    <div className="rounded-lg border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">
      {message}
    </div>
  );
}
