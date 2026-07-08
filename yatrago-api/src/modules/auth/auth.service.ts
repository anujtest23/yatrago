import {
  Injectable,
  BadRequestException,
  UnauthorizedException,
  NotFoundException,
  ForbiddenException,
  Logger,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { createHash, randomBytes, randomInt } from 'crypto';
import { PrismaService } from '../../database/prisma.service';
import { RedisService } from './redis.service';
import { SendOtpDto } from './dto/send-otp.dto';
import { VerifyOtpDto } from './dto/verify-otp.dto';
import { appConfig } from '../../config/app.config';
import { SmsService } from '../platform/sms.service';
import { AuditService } from '../platform/audit.service';
import { FraudService } from '../platform/fraud.service';
import {
  LoginAnomalyService,
  LoginAssessment,
} from '../platform/login-anomaly.service';
import { MetricsService } from '../platform/metrics.service';
import { SecurityAlertsService } from '../platform/security-alerts.service';
import { TotpService } from './totp.service';

/** Request context captured by the controller for auditing/session records. */
export interface RequestContext {
  ip: string;
  deviceInfo?: string;
  /** Client-generated stable device identifier (X-Device-Id header). */
  deviceId?: string;
  /** Self-reported runtime flags (X-Device-Integrity): rooted, emulator… */
  integrityFlags?: string[];
}

const OTP_SENDS_PER_PHONE = 3; // per 10 minutes
const OTP_SENDS_PER_IP = 10; // per hour
const OTP_MAX_FAILED_ATTEMPTS = 5; // per 10 minutes

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    private prisma: PrismaService,
    private redis: RedisService,
    private jwt: JwtService,
    private sms: SmsService,
    private audit: AuditService,
    private fraud: FraudService,
    private anomaly: LoginAnomalyService,
    private metrics: MetricsService,
    private alerts: SecurityAlertsService,
    private totp: TotpService,
  ) {}

  // ── Helpers ─────────────────────────────────────────────────

  /** CSPRNG 6-digit OTP (never Math.random — predictable). */
  private generateOtp(): string {
    return randomInt(0, 1_000_000).toString().padStart(6, '0');
  }

  /** Mask a phone number for logs: +9779812345678 → +97798******78 */
  private maskPhone(phone: string): string {
    return phone.slice(0, 6) + '******' + phone.slice(-2);
  }

  private hashToken(token: string): string {
    return createHash('sha256').update(token).digest('hex');
  }

  private sanitizeDeviceInfo(raw?: string): string | undefined {
    if (!raw) return undefined;
    // eslint-disable-next-line no-control-regex
    return raw.replace(/[\x00-\x1f\x7f]/g, '').slice(0, 256) || undefined;
  }

  /**
   * Issue an access JWT + opaque refresh token and persist the session.
   * The refresh token is 384 bits of CSPRNG output; only its SHA-256 hash
   * is stored. `familyId` links rotations for theft detection.
   */
  private async generateTokens(
    userId: string,
    ctx: RequestContext,
    familyId?: string,
    sessionTtlSeconds = appConfig.refreshTokenTtlSeconds,
    assessment?: LoginAssessment,
  ) {
    const accessToken = this.jwt.sign(
      { sub: userId, type: 'access' },
      {
        secret: appConfig.jwtAccessSecret,
        expiresIn: appConfig.jwtExpiresIn,
        issuer: appConfig.jwtIssuer,
        audience: appConfig.jwtAudience,
      },
    );

    const refreshToken = randomBytes(48).toString('base64url');
    const expiresAt = new Date(Date.now() + sessionTtlSeconds * 1000);

    await this.prisma.authSession.create({
      data: {
        userId,
        tokenHash: this.hashToken(refreshToken),
        familyId: familyId ?? randomBytes(16).toString('hex'),
        deviceInfo: this.sanitizeDeviceInfo(ctx.deviceInfo),
        ipAddress: ctx.ip,
        deviceId:
          assessment?.deviceIdHash ??
          this.anomaly.hashDeviceId(ctx.deviceId) ??
          undefined,
        country: assessment?.geo.country ?? undefined,
        geoLat: assessment?.geo.lat ?? undefined,
        geoLng: assessment?.geo.lng ?? undefined,
        expiresAt,
      },
    });

    return { accessToken, refreshToken };
  }

  /** Cap concurrent sessions per user; evict + blacklist the oldest. */
  private async enforceSessionLimit(userId: string): Promise<void> {
    const sessions = await this.prisma.authSession.findMany({
      where: { userId },
      orderBy: { lastUsedAt: 'desc' },
      skip: appConfig.maxSessionsPerUser - 1,
      select: { id: true, tokenHash: true, familyId: true },
    });
    if (sessions.length === 0) return;

    await this.prisma.authSession.deleteMany({
      where: { id: { in: sessions.map((s) => s.id) } },
    });
    await Promise.all(
      sessions.map((s) =>
        this.redis.blacklistRefreshHash(
          s.tokenHash,
          s.familyId,
          appConfig.refreshTokenTtlSeconds,
        ),
      ),
    );
  }

  // ── POST /auth/send-otp ─────────────────────────────────────

  async sendOtp(dto: SendOtpDto, ctx: RequestContext) {
    // Layered rate limits: per-IP (SIM-rotation spam) and per-phone.
    const ipCount = await this.redis.incrementOtpIpCount(ctx.ip);
    if (ipCount > OTP_SENDS_PER_IP) {
      this.logger.warn(`OTP IP limit hit: ${ctx.ip}`);
      throw new BadRequestException(
        'Too many OTP requests. Please try again later.',
      );
    }

    const sendCount = await this.redis.incrementOtpSendCount(dto.phoneNumber);
    if (sendCount > OTP_SENDS_PER_PHONE) {
      throw new BadRequestException(
        'Too many OTP requests. Please try again in 10 minutes.',
      );
    }

    const otp = this.generateOtp();
    this.metrics.otpSends.inc();
    await this.redis.setOtp(dto.phoneNumber, otp);
    await this.sms.send(
      dto.phoneNumber,
      `Your YatraGo OTP is ${otp}. Valid for 5 minutes. Do not share this with anyone.`,
    );

    this.logger.log(`OTP sent to ${this.maskPhone(dto.phoneNumber)}`);

    return {
      message: 'OTP sent successfully',
      // Development convenience only; production never reaches this branch.
      ...(appConfig.nodeEnv === 'development' && { otp }),
    };
  }

  // ── POST /auth/verify-otp ───────────────────────────────────

  async verifyOtp(dto: VerifyOtpDto, ctx: RequestContext) {
    const failCount = await this.redis.getOtpFailCount(dto.phoneNumber);
    if (failCount >= OTP_MAX_FAILED_ATTEMPTS) {
      this.metrics.otpLockouts.inc();
      this.alerts.record('otp_lockout');
      await this.audit.log(
        'anonymous',
        'auth.otp_lockout',
        'phone',
        undefined,
        { phone: this.maskPhone(dto.phoneNumber), ip: ctx.ip },
      );
      const lockedUser = await this.prisma.user.findUnique({
        where: { phoneNumber: dto.phoneNumber },
        select: { id: true },
      });
      if (lockedUser) {
        await this.fraud.record(lockedUser.id, 'otp_lockout', 10, {
          ip: ctx.ip,
        });
      }
      throw new BadRequestException(
        'Too many failed attempts. Please try again in 10 minutes.',
      );
    }

    if (!(await this.redis.hasOtp(dto.phoneNumber))) {
      throw new BadRequestException(
        'OTP expired or not found. Please request a new one.',
      );
    }

    if (!(await this.redis.verifyOtp(dto.phoneNumber, dto.otp))) {
      this.metrics.otpFailures.inc();
      await this.redis.incrementOtpFailCount(dto.phoneNumber);
      throw new BadRequestException('Invalid OTP. Please try again.');
    }

    // Single use: destroy immediately after successful verification.
    await this.redis.deleteOtp(dto.phoneNumber);
    await this.redis.clearOtpFailCount(dto.phoneNumber);

    let user = await this.prisma.user.findUnique({
      where: { phoneNumber: dto.phoneNumber },
    });

    const isNewUser = !user;

    if (!user) {
      user = await this.prisma.user.create({
        data: { phoneNumber: dto.phoneNumber },
      });
    } else if (!user.isActive) {
      if (user.deletionRequestedAt) {
        // Grace-period recovery: logging in cancels a pending deletion.
        user = await this.prisma.user.update({
          where: { id: user.id },
          data: { deletionRequestedAt: null, isActive: true },
        });
      } else {
        // isActive false without a deletion request = blocked by admin.
        throw new ForbiddenException('Account suspended');
      }
    }

    // Second factor gate: accounts with TOTP enrolled never get tokens
    // straight from an OTP — they must pass /auth/totp/verify first.
    if (user.totpEnabledAt) {
      return {
        message: 'MFA code required',
        mfaRequired: true,
        mfaToken: this.totp.issueMfaToken(user.id),
      };
    }

    await this.notifyNewDeviceLogin(user.id, isNewUser, ctx);
    // Geo/device anomaly signals (country change, impossible travel, Tor,
    // account farming). Never blocks the login — feeds the fraud score.
    const assessment = await this.anomaly.assessLogin(user, ctx, isNewUser);
    await this.enforceSessionLimit(user.id);
    // Privileged accounts get short sessions: hours, not weeks.
    const sessionTtl =
      user.role === 'user'
        ? appConfig.refreshTokenTtlSeconds
        : appConfig.adminRefreshTtlSeconds;
    const tokens = await this.generateTokens(
      user.id,
      ctx,
      undefined,
      sessionTtl,
      assessment,
    );

    await this.audit.log(user.id, 'auth.login', 'user', user.id, {
      ip: ctx.ip,
      deviceInfo: this.sanitizeDeviceInfo(ctx.deviceInfo),
      isNewUser,
    });

    return {
      message: isNewUser ? 'Account created successfully' : 'Login successful',
      isNewUser,
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      user: {
        id: user.id,
        phoneNumber: user.phoneNumber,
        fullName: user.fullName,
        profilePhotoUrl: user.profilePhotoUrl,
        activeMode: user.activeMode,
        role: user.role,
        isVerified: user.isVerified,
      },
    };
  }

  // ── POST /auth/totp/verify (completes an MFA login) ─────────

  async completeMfaLogin(mfaToken: string, code: string, ctx: RequestContext) {
    const userId = await this.totp.verifyChallenge(mfaToken, code);

    const user = await this.prisma.user.findUniqueOrThrow({
      where: { id: userId },
    });

    await this.notifyNewDeviceLogin(user.id, false, ctx);
    const assessment = await this.anomaly.assessLogin(user, ctx, false);
    await this.enforceSessionLimit(user.id);
    const sessionTtl =
      user.role === 'user'
        ? appConfig.refreshTokenTtlSeconds
        : appConfig.adminRefreshTtlSeconds;
    const tokens = await this.generateTokens(
      user.id,
      ctx,
      undefined,
      sessionTtl,
      assessment,
    );

    await this.audit.log(user.id, 'auth.login', 'user', user.id, {
      ip: ctx.ip,
      deviceInfo: this.sanitizeDeviceInfo(ctx.deviceInfo),
      mfa: true,
    });

    return {
      message: 'Login successful',
      isNewUser: false,
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      user: {
        id: user.id,
        phoneNumber: user.phoneNumber,
        fullName: user.fullName,
        profilePhotoUrl: user.profilePhotoUrl,
        activeMode: user.activeMode,
        role: user.role,
        isVerified: user.isVerified,
      },
    };
  }

  /**
   * Account-takeover signal: SMS the owner when a login arrives from a
   * device we have not seen among their active sessions.
   */
  private async notifyNewDeviceLogin(
    userId: string,
    isNewUser: boolean,
    ctx: RequestContext,
  ): Promise<void> {
    if (isNewUser) return;
    try {
      const device = this.sanitizeDeviceInfo(ctx.deviceInfo);
      const sessions = await this.prisma.authSession.findMany({
        where: { userId, expiresAt: { gt: new Date() } },
        select: { deviceInfo: true },
      });
      if (sessions.length === 0) return; // first login in a while — noise
      if (sessions.some((s) => s.deviceInfo === device)) return;

      const user = await this.prisma.user.findUnique({
        where: { id: userId },
        select: { phoneNumber: true },
      });
      if (user) {
        await this.sms.send(
          user.phoneNumber,
          'YatraGo: your account was just accessed from a new device. If this was not you, open the app and log out of all devices immediately.',
        );
      }
    } catch (error) {
      // Notification failure must never block a legitimate login.
      this.logger.warn(
        `New-device notification failed: ${(error as Error).message}`,
      );
    }
  }

  // ── POST /auth/refresh ──────────────────────────────────────

  async refresh(refreshToken: string, ctx: RequestContext) {
    const tokenHash = this.hashToken(refreshToken);

    // Reuse of an already-rotated token = the token was stolen (either by
    // the attacker or the victim is replaying after the attacker rotated).
    // Fail secure: revoke the entire session family on both devices.
    let stolenFamily: string | null;
    try {
      stolenFamily = await this.redis.getBlacklistedFamily(tokenHash);
    } catch (error) {
      // Fail closed: if the revocation blacklist is unreachable we cannot rule
      // out that this token was already rotated/stolen, so refuse the refresh
      // rather than proceed blind (CWE-636).
      this.logger.error(
        `Refresh blacklist lookup failed — denying refresh: ${(error as Error).message}`,
      );
      throw new UnauthorizedException('Invalid or expired refresh token');
    }
    if (stolenFamily) {
      const revoked = await this.prisma.authSession.findMany({
        where: { familyId: stolenFamily },
        select: { id: true, userId: true, tokenHash: true },
      });
      if (revoked.length > 0) {
        await this.prisma.authSession.deleteMany({
          where: { familyId: stolenFamily },
        });
        await Promise.all(
          revoked.map((s) =>
            this.redis.blacklistRefreshHash(
              s.tokenHash,
              stolenFamily,
              appConfig.refreshTokenTtlSeconds,
            ),
          ),
        );
        await this.audit.log(
          revoked[0].userId,
          'auth.refresh_reuse_detected',
          'user',
          revoked[0].userId,
          { ip: ctx.ip, familyId: stolenFamily },
        );
        await this.fraud.record(revoked[0].userId, 'refresh_reuse', 30, {
          ip: ctx.ip,
          familyId: stolenFamily,
        });
        this.metrics.refreshReuse.inc();
        this.alerts.record('refresh_reuse');
        this.logger.warn(
          `Refresh token reuse detected — family ${stolenFamily} revoked`,
        );
      }
      throw new UnauthorizedException('Invalid or expired refresh token');
    }

    const session = await this.prisma.authSession.findUnique({
      where: { tokenHash },
    });
    if (!session || session.expiresAt < new Date()) {
      throw new UnauthorizedException('Invalid or expired refresh token');
    }

    const user = await this.prisma.user.findUnique({
      where: { id: session.userId },
    });
    if (!user || !user.isActive) {
      throw new UnauthorizedException('Invalid or expired refresh token');
    }

    // Inactivity timeout for privileged accounts (OWASP ASVS 3.3.2): the
    // gap since the session row was minted is the idle time — an active
    // client rotates every ~15 min with its access token.
    if (
      user.role !== 'user' &&
      Date.now() - session.lastUsedAt.getTime() >
        appConfig.adminInactivityTimeoutSeconds * 1000
    ) {
      await this.prisma.authSession.delete({ where: { id: session.id } });
      await this.redis.blacklistRefreshHash(
        tokenHash,
        session.familyId,
        appConfig.refreshTokenTtlSeconds,
      );
      await this.audit.log(
        user.id,
        'auth.admin_session_idle_timeout',
        'auth_session',
        session.id,
      );
      throw new UnauthorizedException('Session expired due to inactivity');
    }

    // Rotate: retire the old session, blacklist its hash, keep the family.
    await this.prisma.authSession.delete({ where: { id: session.id } });
    await this.redis.blacklistRefreshHash(
      tokenHash,
      session.familyId,
      appConfig.refreshTokenTtlSeconds,
    );

    const sessionTtl =
      user.role === 'user'
        ? appConfig.refreshTokenTtlSeconds
        : appConfig.adminRefreshTtlSeconds;
    // Preserve the device identity across rotations (header wins, else the
    // retiring session's value) and refresh the geo columns from this IP.
    const tokens = await this.generateTokens(
      user.id,
      ctx,
      session.familyId,
      sessionTtl,
      {
        geo: this.anomaly.lookupGeo(ctx.ip),
        deviceIdHash:
          this.anomaly.hashDeviceId(ctx.deviceId) ?? session.deviceId,
      },
    );

    return {
      message: 'Tokens refreshed',
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    };
  }

  // ── POST /auth/logout ───────────────────────────────────────

  async logout(refreshToken: string) {
    const tokenHash = this.hashToken(refreshToken);

    const session = await this.prisma.authSession.findUnique({
      where: { tokenHash },
      select: { id: true, familyId: true },
    });
    if (session) {
      await this.prisma.authSession.delete({ where: { id: session.id } });
      await this.redis.blacklistRefreshHash(
        tokenHash,
        session.familyId,
        appConfig.refreshTokenTtlSeconds,
      );
    }

    // Same response whether or not the token existed — no revocation oracle.
    return { message: 'Logged out successfully' };
  }

  // ── POST /auth/logout-all ───────────────────────────────────

  async logoutAll(userId: string) {
    const sessions = await this.prisma.authSession.findMany({
      where: { userId },
      select: { tokenHash: true, familyId: true },
    });

    await this.prisma.authSession.deleteMany({ where: { userId } });
    await Promise.all(
      sessions.map((s) =>
        this.redis.blacklistRefreshHash(
          s.tokenHash,
          s.familyId,
          appConfig.refreshTokenTtlSeconds,
        ),
      ),
    );

    await this.audit.log(userId, 'auth.logout_all', 'user', userId, {
      sessionsRevoked: sessions.length,
    });

    return { message: 'Logged out from all devices', count: sessions.length };
  }

  // ── GET /auth/sessions ──────────────────────────────────────

  async listSessions(userId: string) {
    return this.prisma.authSession.findMany({
      where: { userId, expiresAt: { gt: new Date() } },
      orderBy: { lastUsedAt: 'desc' },
      select: {
        id: true,
        deviceInfo: true,
        ipAddress: true,
        lastUsedAt: true,
        createdAt: true,
      },
    });
  }

  // ── DELETE /auth/sessions/:id ───────────────────────────────

  async revokeSession(userId: string, sessionId: string) {
    // Ownership enforced in the WHERE clause — no cross-user revocation.
    const session = await this.prisma.authSession.findFirst({
      where: { id: sessionId, userId },
      select: { id: true, tokenHash: true, familyId: true },
    });
    if (!session) {
      throw new NotFoundException('Session not found');
    }

    await this.prisma.authSession.delete({ where: { id: session.id } });
    await this.redis.blacklistRefreshHash(
      session.tokenHash,
      session.familyId,
      appConfig.refreshTokenTtlSeconds,
    );

    await this.audit.log(
      userId,
      'auth.session_revoked',
      'auth_session',
      sessionId,
    );

    return { message: 'Session revoked' };
  }

  // ── GET /auth/me ────────────────────────────────────────────

  async getMe(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        phoneNumber: true,
        fullName: true,
        profilePhotoUrl: true,
        gender: true,
        dateOfBirth: true,
        activeMode: true,
        role: true,
        isVerified: true,
        createdAt: true,
        driverProfile: {
          select: {
            verificationStatus: true,
            averageRating: true,
            totalTrips: true,
          },
        },
      },
    });

    if (!user) {
      throw new NotFoundException('User not found');
    }

    return user;
  }
}
