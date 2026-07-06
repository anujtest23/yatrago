import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { authenticator } from 'otplib';
import { PrismaService } from '../../database/prisma.service';
import { RedisService } from './redis.service';
import { EncryptionService } from '../platform/encryption.service';
import { AuditService } from '../platform/audit.service';
import { appConfig } from '../../config/app.config';

const TOTP_MAX_FAILS = 5; // per 10-minute window (Redis counter)

/**
 * TOTP second factor for privileged accounts (SECURITY.md: admin MFA).
 *
 * Enrollment: setup → scan QR / enter secret → enable with a valid code.
 * Once enabled, OTP login for that account returns `mfaRequired` plus a
 * 5-minute single-purpose mfaToken; only /auth/totp/verify with a valid
 * code completes the login and mints real tokens.
 */
@Injectable()
export class TotpService {
  constructor(
    private prisma: PrismaService,
    private redis: RedisService,
    private jwt: JwtService,
    private encryption: EncryptionService,
    private audit: AuditService,
  ) {
    // ±1 time-step tolerance for clock drift; standard 30s/6-digit TOTP.
    authenticator.options = { window: 1 };
  }

  private assertPrivileged(role: string) {
    if (role !== 'admin' && role !== 'super_admin') {
      throw new ForbiddenException('MFA is available for admin accounts');
    }
  }

  private async checkFailCounter(userId: string) {
    const fails = await this.redis.getTotpFailCount(userId);
    if (fails >= TOTP_MAX_FAILS) {
      throw new BadRequestException(
        'Too many failed codes. Please try again in 10 minutes.',
      );
    }
  }

  // ── POST /auth/totp/setup ──────────────────────────────────

  async setup(userId: string, role: string) {
    this.assertPrivileged(role);

    const user = await this.prisma.user.findUniqueOrThrow({
      where: { id: userId },
      select: { phoneNumber: true, totpEnabledAt: true },
    });
    if (user.totpEnabledAt) {
      throw new BadRequestException('MFA is already enabled');
    }

    const secret = authenticator.generateSecret(20);
    await this.prisma.user.update({
      where: { id: userId },
      data: { totpSecret: this.encryption.encrypt(secret) },
    });

    return {
      secret,
      otpauthUrl: authenticator.keyuri(
        user.phoneNumber,
        'YatraGo Admin',
        secret,
      ),
      message: 'Scan the QR code, then confirm with a code to enable MFA.',
    };
  }

  // ── POST /auth/totp/enable ─────────────────────────────────

  async enable(userId: string, role: string, code: string) {
    this.assertPrivileged(role);
    await this.checkFailCounter(userId);

    const user = await this.prisma.user.findUniqueOrThrow({
      where: { id: userId },
      select: { totpSecret: true, totpEnabledAt: true },
    });
    if (user.totpEnabledAt) {
      throw new BadRequestException('MFA is already enabled');
    }
    if (!user.totpSecret) {
      throw new BadRequestException('Run MFA setup first');
    }

    if (
      !authenticator.verify({
        token: code,
        secret: this.encryption.decrypt(user.totpSecret),
      })
    ) {
      await this.redis.incrementTotpFailCount(userId);
      throw new BadRequestException('Invalid code');
    }

    await this.prisma.user.update({
      where: { id: userId },
      data: { totpEnabledAt: new Date() },
    });
    await this.redis.clearTotpFailCount(userId);
    await this.audit.log(userId, 'auth.mfa_enabled', 'user', userId);

    return { message: 'MFA enabled' };
  }

  // ── POST /auth/totp/disable ────────────────────────────────

  async disable(userId: string, role: string, code: string) {
    this.assertPrivileged(role);
    await this.checkFailCounter(userId);

    const user = await this.prisma.user.findUniqueOrThrow({
      where: { id: userId },
      select: { totpSecret: true, totpEnabledAt: true },
    });
    if (!user.totpEnabledAt || !user.totpSecret) {
      throw new BadRequestException('MFA is not enabled');
    }

    if (
      !authenticator.verify({
        token: code,
        secret: this.encryption.decrypt(user.totpSecret),
      })
    ) {
      await this.redis.incrementTotpFailCount(userId);
      throw new BadRequestException('Invalid code');
    }

    await this.prisma.user.update({
      where: { id: userId },
      data: { totpSecret: null, totpEnabledAt: null },
    });
    await this.redis.clearTotpFailCount(userId);
    await this.audit.log(userId, 'auth.mfa_disabled', 'user', userId);

    return { message: 'MFA disabled' };
  }

  // ── MFA challenge plumbing (used by AuthService) ───────────

  /** Short-lived single-purpose token bridging OTP success → TOTP check. */
  issueMfaToken(userId: string): string {
    return this.jwt.sign(
      { sub: userId, type: 'mfa' },
      {
        secret: appConfig.jwtAccessSecret,
        expiresIn: 300,
        issuer: appConfig.jwtIssuer,
        audience: appConfig.jwtAudience,
      },
    );
  }

  /** Validates the mfaToken + TOTP code; returns the userId on success. */
  async verifyChallenge(mfaToken: string, code: string): Promise<string> {
    let payload: { sub: string; type: string };
    try {
      payload = this.jwt.verify(mfaToken, {
        secret: appConfig.jwtAccessSecret,
        issuer: appConfig.jwtIssuer,
        audience: appConfig.jwtAudience,
      });
    } catch {
      throw new UnauthorizedException('MFA challenge expired. Log in again.');
    }
    if (payload.type !== 'mfa') {
      throw new UnauthorizedException('Invalid MFA token');
    }

    await this.checkFailCounter(payload.sub);

    const user = await this.prisma.user.findUnique({
      where: { id: payload.sub },
      select: {
        id: true,
        totpSecret: true,
        totpEnabledAt: true,
        isActive: true,
      },
    });
    if (!user || !user.isActive || !user.totpEnabledAt || !user.totpSecret) {
      throw new UnauthorizedException('Invalid MFA token');
    }

    if (
      !authenticator.verify({
        token: code,
        secret: this.encryption.decrypt(user.totpSecret),
      })
    ) {
      await this.redis.incrementTotpFailCount(user.id);
      throw new UnauthorizedException('Invalid code');
    }

    await this.redis.clearTotpFailCount(user.id);
    return user.id;
  }
}
