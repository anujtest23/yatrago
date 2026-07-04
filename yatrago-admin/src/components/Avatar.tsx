import { resolveFileUrl } from '../api/client';
import { initials } from '../lib/format';

export function Avatar({
  name,
  photoUrl,
  size = 36,
}: {
  name?: string | null;
  photoUrl?: string | null;
  size?: number;
}) {
  const src = resolveFileUrl(photoUrl);
  if (src) {
    return (
      <img
        src={src}
        alt={name ?? ''}
        style={{ width: size, height: size }}
        className="rounded-full object-cover"
      />
    );
  }
  return (
    <div
      style={{ width: size, height: size, fontSize: size * 0.36 }}
      className="flex items-center justify-center rounded-full bg-slate-200 font-semibold text-slate-600"
    >
      {initials(name)}
    </div>
  );
}
