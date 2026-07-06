import { Injectable, Logger } from '@nestjs/common';
import {
  DeleteObjectCommand,
  GetObjectCommand,
  PutObjectCommand,
  S3Client,
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { createReadStream, existsSync } from 'fs';
import { readFile, unlink } from 'fs/promises';
import { join, resolve } from 'path';
import type { Response } from 'express';
import { appConfig } from '../../config/app.config';

const LOCAL_KYC_ROOT = resolve('./uploads-private/kyc');

/**
 * Abstracts private-document storage behind one interface so the rest of the
 * app never cares whether files live on local disk (dev / single node) or in
 * a Cloudflare R2 private bucket (production / multi-node).
 *
 * Backend is chosen at boot from config: R2 when credentials are present,
 * local disk otherwise. Multi-instance deployments MUST use R2 — local disk
 * is not shared across nodes.
 */
@Injectable()
export class StorageService {
  private readonly logger = new Logger(StorageService.name);
  private readonly r2: S3Client | null;

  constructor() {
    if (
      appConfig.r2AccountId &&
      appConfig.r2AccessKey &&
      appConfig.r2SecretKey
    ) {
      this.r2 = new S3Client({
        region: 'auto',
        endpoint: `https://${appConfig.r2AccountId}.r2.cloudflarestorage.com`,
        credentials: {
          accessKeyId: appConfig.r2AccessKey,
          secretAccessKey: appConfig.r2SecretKey,
        },
      });
      this.logger.log('Storage backend: Cloudflare R2 (private bucket)');
    } else {
      this.r2 = null;
      this.logger.log('Storage backend: local disk (uploads-private/)');
    }
  }

  get usesR2(): boolean {
    return this.r2 !== null;
  }

  /**
   * Promote a just-uploaded local temp file into permanent storage under the
   * given key. On R2 this uploads then removes the temp file; on local disk
   * the file already lives in the right place, so this is a no-op.
   */
  async persistFromLocal(
    localPath: string,
    key: string,
    contentType: string,
  ): Promise<void> {
    if (!this.r2) return; // local disk: multer already wrote it in place
    const body = await readFile(localPath);
    await this.r2.send(
      new PutObjectCommand({
        Bucket: appConfig.r2BucketName,
        Key: key,
        Body: body,
        ContentType: contentType,
      }),
    );
    await unlink(localPath).catch(() => undefined);
  }

  /** Presigned GET URL for R2; null for local (served via FilesController). */
  async getPresignedUrl(key: string, ttlSeconds = 900): Promise<string | null> {
    if (!this.r2) return null;
    return getSignedUrl(
      this.r2,
      new GetObjectCommand({ Bucket: appConfig.r2BucketName, Key: key }),
      { expiresIn: ttlSeconds },
    );
  }

  /** Stream a locally stored private file to an HTTP response. */
  streamLocal(key: string, res: Response): boolean {
    const filename = key.replace(/^kyc\//, '');
    const path = join(LOCAL_KYC_ROOT, filename);
    if (!existsSync(path)) return false;
    createReadStream(path).pipe(res);
    return true;
  }

  async delete(key: string): Promise<void> {
    if (this.r2) {
      await this.r2.send(
        new DeleteObjectCommand({
          Bucket: appConfig.r2BucketName,
          Key: key,
        }),
      );
    } else {
      const filename = key.replace(/^kyc\//, '');
      await unlink(join(LOCAL_KYC_ROOT, filename)).catch(() => undefined);
    }
  }
}
