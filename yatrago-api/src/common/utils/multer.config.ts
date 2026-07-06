import { diskStorage } from 'multer';
import { randomUUID } from 'crypto';
import { mkdirSync } from 'fs';
import { BadRequestException } from '@nestjs/common';

/**
 * Upload security model:
 *  - Filenames are server-generated UUIDs; the client-supplied name is never
 *    used (kills path traversal, double extensions, and stored-XSS via
 *    .html/.svg names on the static route).
 *  - The stored extension is derived from the ACCEPTED MIME type, not from
 *    the original filename.
 *  - MIME whitelist here is only the first gate — FileSignatureInterceptor
 *    verifies magic bytes after write, because client MIME is attacker-
 *    controlled.
 *  - KYC documents go to a PRIVATE directory outside the public static
 *    root and are only reachable through short-lived signed URLs.
 */

export const PUBLIC_UPLOAD_DIR = './uploads';
export const PRIVATE_KYC_DIR = './uploads-private/kyc';

const IMAGE_MIME_EXT: Record<string, string> = {
  'image/jpeg': '.jpg',
  'image/jpg': '.jpg',
  'image/png': '.png',
  'image/webp': '.webp',
};

const DOCUMENT_MIME_EXT: Record<string, string> = {
  ...IMAGE_MIME_EXT,
  'application/pdf': '.pdf',
};

function makeConfig(
  destination: string,
  mimeExtMap: Record<string, string>,
  maxSizeMb: number,
) {
  return {
    storage: diskStorage({
      destination: (_req, _file, cb) => {
        mkdirSync(destination, { recursive: true });
        cb(null, destination);
      },
      filename: (_req, file, cb) => {
        cb(null, randomUUID() + mimeExtMap[file.mimetype]);
      },
    }),
    limits: { fileSize: maxSizeMb * 1024 * 1024, files: 1 },
    fileFilter: (
      _req: unknown,
      file: Express.Multer.File,
      cb: (error: Error | null, acceptFile: boolean) => void,
    ) => {
      if (!mimeExtMap[file.mimetype]) {
        cb(new BadRequestException('File type not allowed'), false);
      } else {
        cb(null, true);
      }
    },
  };
}

/** Public images (profile photos): jpg/png/webp, 5 MB. */
export const publicImageMulterConfig = makeConfig(
  PUBLIC_UPLOAD_DIR,
  IMAGE_MIME_EXT,
  5,
);

/**
 * KYC / vehicle documents: images + PDF, 10 MB, stored PRIVATELY.
 * Kept under the historic export name so existing imports stay valid.
 */
export const imageMulterConfig = makeConfig(
  PRIVATE_KYC_DIR,
  DOCUMENT_MIME_EXT,
  10,
);
