import {
  Controller,
  Get,
  NotFoundException,
  Param,
  Query,
  Res,
} from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import type { Response } from 'express';
import { FileSignerService } from './file-signer.service';
import { StorageService } from './storage.service';

// Server-generated names only: UUID + whitelisted extension. Anything else
// (traversal sequences, alternate extensions) fails before touching storage.
const SAFE_FILENAME = /^[0-9a-fA-F-]{36}\.(jpg|png|webp|pdf)$/;

const CONTENT_TYPES: Record<string, string> = {
  jpg: 'image/jpeg',
  png: 'image/png',
  webp: 'image/webp',
  pdf: 'application/pdf',
};

@ApiTags('Files')
@Controller('files')
export class FilesController {
  constructor(
    private signer: FileSignerService,
    private storage: StorageService,
  ) {}

  @Throttle({ default: { limit: 60, ttl: 60_000 } })
  @Get('kyc/:filename')
  @ApiOperation({ summary: 'Fetch a private KYC document via signed URL' })
  async getKycFile(
    @Param('filename') filename: string,
    @Query('exp') exp: string,
    @Query('sig') sig: string,
    @Res() res: Response,
  ) {
    // Generic 404 for every failure mode — no oracle distinguishing
    // "bad signature" from "no such file".
    if (!SAFE_FILENAME.test(filename)) throw new NotFoundException();
    const key = `kyc/${filename}`;
    if (!this.signer.verify(key, parseInt(exp, 10), sig ?? '')) {
      throw new NotFoundException();
    }

    // R2 backend: hand the client a short-lived presigned URL and redirect,
    // so document bytes never proxy through the API node.
    if (this.storage.usesR2) {
      const presigned = await this.storage.getPresignedUrl(key, 120);
      if (!presigned) throw new NotFoundException();
      res.redirect(302, presigned);
      return;
    }

    const ext = filename.split('.').pop()!.toLowerCase();
    res.setHeader('Content-Type', CONTENT_TYPES[ext]);
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('Cache-Control', 'private, max-age=300');
    // Neutralize active content (PDF JavaScript) when rendered in-browser.
    res.setHeader('Content-Security-Policy', "default-src 'none'; sandbox");
    if (ext === 'pdf') {
      res.setHeader(
        'Content-Disposition',
        `attachment; filename="${filename}"`,
      );
    }

    if (!this.storage.streamLocal(key, res)) {
      throw new NotFoundException();
    }
  }
}
