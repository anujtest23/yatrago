import type { ReactNode } from 'react';
import { Button } from './ui';

export function Table({ children }: { children: ReactNode }) {
  return (
    <div className="overflow-x-auto">
      <table className="min-w-full divide-y divide-slate-200 text-sm">
        {children}
      </table>
    </div>
  );
}

export function THead({ cols }: { cols: string[] }) {
  return (
    <thead className="bg-slate-50">
      <tr>
        {cols.map((c) => (
          <th
            key={c}
            className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-slate-500"
          >
            {c}
          </th>
        ))}
      </tr>
    </thead>
  );
}

export function TBody({ children }: { children: ReactNode }) {
  return <tbody className="divide-y divide-slate-100">{children}</tbody>;
}

export function TR({ children }: { children: ReactNode }) {
  return <tr className="hover:bg-slate-50/70">{children}</tr>;
}

export function TD({
  children,
  className = '',
}: {
  children: ReactNode;
  className?: string;
}) {
  return (
    <td className={`px-4 py-3 align-middle text-slate-700 ${className}`}>
      {children}
    </td>
  );
}

export function Pagination({
  page,
  totalPages,
  total,
  onChange,
}: {
  page: number;
  totalPages: number;
  total: number;
  onChange: (page: number) => void;
}) {
  if (totalPages <= 1) {
    return (
      <div className="px-4 py-3 text-xs text-slate-400">{total} record(s)</div>
    );
  }
  return (
    <div className="flex items-center justify-between border-t border-slate-100 px-4 py-3">
      <span className="text-xs text-slate-400">
        Page {page} of {totalPages} · {total} record(s)
      </span>
      <div className="flex gap-2">
        <Button
          variant="secondary"
          disabled={page <= 1}
          onClick={() => onChange(page - 1)}
        >
          Previous
        </Button>
        <Button
          variant="secondary"
          disabled={page >= totalPages}
          onClick={() => onChange(page + 1)}
        >
          Next
        </Button>
      </div>
    </div>
  );
}
