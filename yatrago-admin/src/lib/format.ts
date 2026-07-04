export function npr(amount?: number | null): string {
  return `NPR ${(amount ?? 0).toLocaleString('en-IN')}`;
}

export function dateTime(iso?: string | null): string {
  if (!iso) return '—';
  return new Date(iso).toLocaleString('en-GB', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
}

export function dateOnly(iso?: string | null): string {
  if (!iso) return '—';
  return new Date(iso).toLocaleDateString('en-GB', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
  });
}

export function initials(name?: string | null): string {
  if (!name) return '?';
  return name
    .trim()
    .split(/\s+/)
    .slice(0, 2)
    .map((p) => p[0]?.toUpperCase() ?? '')
    .join('');
}

// Human label for config keys shown on the Settings page.
export function configLabel(key: string): string {
  return key
    .replace(/_/g, ' ')
    .replace(/npr/i, 'NPR')
    .replace(/\b\w/g, (c) => c.toUpperCase());
}
