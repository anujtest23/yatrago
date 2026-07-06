import { Injectable } from '@nestjs/common';
import {
  createCipheriv,
  createDecipheriv,
  createHash,
  randomBytes,
} from 'crypto';
import { appConfig } from '../../config/app.config';

/**
 * Application-layer field encryption for PII at rest (AES-256-GCM).
 *
 * Used for: TOTP secrets, payout account references, and any future
 * sensitive column. Ciphertext format: `enc:v1:<iv>:<tag>:<data>` (base64url
 * segments), so plaintext legacy values are trivially distinguishable and
 * can be migrated lazily.
 *
 * Key: ENCRYPTION_KEY env (any string ≥32 chars; hashed to 256 bits).
 * Falls back to the refresh secret outside production so development
 * works with zero extra setup — production requires an explicit key when
 * any encrypted feature is used.
 */
@Injectable()
export class EncryptionService {
  private readonly key: Buffer = createHash('sha256')
    .update(appConfig.encryptionKey)
    .digest();

  private static readonly PREFIX = 'enc:v1:';

  encrypt(plaintext: string): string {
    const iv = randomBytes(12);
    const cipher = createCipheriv('aes-256-gcm', this.key, iv);
    const data = Buffer.concat([
      cipher.update(plaintext, 'utf8'),
      cipher.final(),
    ]);
    const tag = cipher.getAuthTag();
    return (
      EncryptionService.PREFIX +
      [iv, tag, data].map((b) => b.toString('base64url')).join(':')
    );
  }

  /** Decrypts `enc:v1:` values; passes legacy plaintext through unchanged. */
  decrypt(stored: string): string {
    if (!stored.startsWith(EncryptionService.PREFIX)) return stored;
    const [ivB64, tagB64, dataB64] = stored
      .slice(EncryptionService.PREFIX.length)
      .split(':');
    const decipher = createDecipheriv(
      'aes-256-gcm',
      this.key,
      Buffer.from(ivB64, 'base64url'),
    );
    decipher.setAuthTag(Buffer.from(tagB64, 'base64url'));
    return Buffer.concat([
      decipher.update(Buffer.from(dataB64, 'base64url')),
      decipher.final(),
    ]).toString('utf8');
  }
}
