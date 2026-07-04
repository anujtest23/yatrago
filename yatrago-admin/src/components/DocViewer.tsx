import { resolveFileUrl } from '../api/client';
import { StatusBadge } from './ui';

interface Doc {
  docType: string;
  status?: string;
  fileUrl: string | null;
  rejectionReason?: string | null;
}

// Renders a grid of uploaded documents. Images preview inline; anything else
// (PDFs etc.) shows an "open" link. Clicking an image opens the full file.
export function DocGallery({ docs }: { docs: Doc[] }) {
  if (!docs || docs.length === 0) {
    return (
      <p className="text-sm text-slate-400">No documents uploaded.</p>
    );
  }
  return (
    <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
      {docs.map((d, i) => {
        const url = resolveFileUrl(d.fileUrl);
        const isImage = url && /\.(png|jpe?g|webp|gif)$/i.test(url);
        return (
          <div
            key={`${d.docType}-${i}`}
            className="overflow-hidden rounded-lg border border-slate-200"
          >
            <div className="flex items-center justify-between bg-slate-50 px-3 py-2">
              <span className="text-sm font-medium capitalize text-slate-700">
                {d.docType.replace(/_/g, ' ')}
              </span>
              {d.status && <StatusBadge status={d.status} />}
            </div>
            <div className="flex items-center justify-center bg-slate-100 p-2">
              {url ? (
                isImage ? (
                  <a href={url} target="_blank" rel="noreferrer">
                    <img
                      src={url}
                      alt={d.docType}
                      className="max-h-52 w-auto rounded object-contain"
                    />
                  </a>
                ) : (
                  <a
                    href={url}
                    target="_blank"
                    rel="noreferrer"
                    className="py-8 text-sm font-medium text-blue-600 hover:underline"
                  >
                    Open document ↗
                  </a>
                )
              ) : (
                <span className="py-8 text-sm text-slate-400">No file</span>
              )}
            </div>
            {d.rejectionReason && (
              <p className="bg-rose-50 px-3 py-1.5 text-xs text-rose-600">
                {d.rejectionReason}
              </p>
            )}
          </div>
        );
      })}
    </div>
  );
}
