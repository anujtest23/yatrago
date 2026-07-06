import { Injectable } from '@nestjs/common';
import { createHmac, timingSafeEqual } from 'crypto';
import { appConfig } from '../../config/app.config';

/**
 * HMAC-signed, expiring URLs for privately stored files (KYC documents).
 *
 * Why signed URLs instead of bearer-authenticated file routes: browser
 * <img> tags (admin console) and mobile image widgets cannot attach
 * Authorization headers. A short-lived signature in the query string gives
 * the same possession-based access control without exposing tokens.
 */
@Injectable()
export class FileSignerService {
  private static readonly DEFAULT_TTL_SECONDS = 15 * 60;

  private hmac(payload: string): string {
    return createHmac('sha256', appConfig.fileSigningSecret)
      .update(payload)
      .digest('base64url');
  }

  /** Storage key (e.g. "kyc/uuid.jpg") → signed relative URL. */
  sign(
    storageKey: string,
    ttlSeconds = FileSignerService.DEFAULT_TTL_SECONDS,
  ): string {
    const exp = Math.floor(Date.now() / 1000) + ttlSeconds;
    const sig = this.hmac(`${storageKey}:${exp}`);
    return `/api/v1/files/${storageKey}?exp=${exp}&sig=${sig}`;
  }

  /** Validate signature + expiry for a storage key. */
  verify(storageKey: string, exp: number, sig: string): boolean {
    if (!Number.isFinite(exp) || exp < Math.floor(Date.now() / 1000)) {
      return false;
    }
    const expected = this.hmac(`${storageKey}:${exp}`);
    const a = Buffer.from(expected);
    const b = Buffer.from(sig);
    return a.length === b.length && timingSafeEqual(a, b);
  }

  /**
   * Map a stored fileUrl to what clients receive.
   * New private files are stored as "kyc/<uuid>.<ext>" → signed URL.
   * Legacy rows ("/uploads/...") pass through unchanged.
   */
  toClientUrl(stored: string | null): string | null {
    if (!stored) return stored;
    if (stored.startsWith('kyc/')) return this.sign(stored);
    return stored;
  }
}
