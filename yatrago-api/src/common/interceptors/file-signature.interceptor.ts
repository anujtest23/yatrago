import {
  BadRequestException,
  CallHandler,
  ExecutionContext,
  Injectable,
  NestInterceptor,
} from '@nestjs/common';
import { Observable } from 'rxjs';
import { open, rename, unlink } from 'fs/promises';
import sharp from 'sharp';

/**
 * Post-upload defense for files already written to disk by multer:
 *
 *  1. Magic-byte check — the client MIME type is attacker-controlled, so we
 *     verify actual content signatures. Mismatches are deleted.
 *  2. Image re-encode via sharp — strips EXIF/metadata (GPS coordinates,
 *     device info: a privacy leak) AND neutralizes any polyglot/malicious
 *     payload smuggled inside a technically-valid image. PDFs are left as-is
 *     (already served as sandboxed attachments).
 */
@Injectable()
export class FileSignatureInterceptor implements NestInterceptor {
  async intercept(
    context: ExecutionContext,
    next: CallHandler,
  ): Promise<Observable<unknown>> {
    const req = context.switchToHttp().getRequest();
    const file: Express.Multer.File | undefined = req.file;

    if (file?.path) {
      const valid = await this.matchesSignature(file.path, file.mimetype);
      if (!valid) {
        await unlink(file.path).catch(() => undefined);
        throw new BadRequestException('File content does not match its type');
      }
      await this.sanitizeImage(file);
    }

    return next.handle();
  }

  /** Re-encode images to strip metadata; delete + reject on failure. */
  private async sanitizeImage(file: Express.Multer.File): Promise<void> {
    if (!file.mimetype.startsWith('image/')) return;

    const tmp = `${file.path}.clean`;
    try {
      const pipeline = sharp(file.path, { failOn: 'error' }).rotate(); // bake orientation, drop EXIF
      if (file.mimetype === 'image/png') {
        await pipeline.png().toFile(tmp);
      } else if (file.mimetype === 'image/webp') {
        await pipeline.webp().toFile(tmp);
      } else {
        await pipeline.jpeg({ quality: 90 }).toFile(tmp);
      }
      await rename(tmp, file.path);
    } catch {
      await unlink(tmp).catch(() => undefined);
      await unlink(file.path).catch(() => undefined);
      throw new BadRequestException('Image could not be processed');
    }
  }

  private async matchesSignature(
    path: string,
    mimetype: string,
  ): Promise<boolean> {
    let handle;
    try {
      handle = await open(path, 'r');
      const buf = Buffer.alloc(12);
      const { bytesRead } = await handle.read(buf, 0, 12, 0);
      if (bytesRead < 4) return false;

      switch (mimetype) {
        case 'image/jpeg':
        case 'image/jpg':
          return buf[0] === 0xff && buf[1] === 0xd8 && buf[2] === 0xff;
        case 'image/png':
          return buf
            .subarray(0, 8)
            .equals(
              Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
            );
        case 'image/webp':
          return (
            buf.subarray(0, 4).toString('ascii') === 'RIFF' &&
            buf.subarray(8, 12).toString('ascii') === 'WEBP'
          );
        case 'application/pdf':
          return buf.subarray(0, 5).toString('ascii') === '%PDF-';
        default:
          return false;
      }
    } catch {
      return false;
    } finally {
      await handle?.close().catch(() => undefined);
    }
  }
}
