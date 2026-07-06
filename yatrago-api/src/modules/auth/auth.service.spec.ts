import { Test } from '@nestjs/testing';
import {
  BadRequestException,
  ForbiddenException,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { AuthService, RequestContext } from './auth.service';
import { RedisService } from './redis.service';
import { PrismaService } from '../../database/prisma.service';
import { SmsService } from '../platform/sms.service';
import { AuditService } from '../platform/audit.service';
import { FraudService } from '../platform/fraud.service';
import { LoginAnomalyService } from '../platform/login-anomaly.service';
import { MetricsService } from '../platform/metrics.service';
import { SecurityAlertsService } from '../platform/security-alerts.service';
import { TotpService } from './totp.service';
import { appConfig } from '../../config/app.config';

const ctx: RequestContext = { ip: '203.0.113.7', deviceInfo: 'jest-tests' };

const activeUser = {
  id: 'user-1',
  phoneNumber: '+9779812345678',
  fullName: 'Test User',
  profilePhotoUrl: null,
  activeMode: 'passenger',
  role: 'user',
  isVerified: false,
  isActive: true,
  deletionRequestedAt: null,
};

describe('AuthService', () => {
  let service: AuthService;
  let prisma: {
    user: Record<string, jest.Mock>;
    authSession: Record<string, jest.Mock>;
  };
  let redis: Record<string, jest.Mock>;
  let sms: { send: jest.Mock };
  let audit: { log: jest.Mock };

  beforeEach(async () => {
    prisma = {
      user: {
        findUnique: jest.fn(),
        create: jest.fn(),
        update: jest.fn(),
      },
      authSession: {
        create: jest.fn().mockResolvedValue({}),
        findUnique: jest.fn(),
        findFirst: jest.fn(),
        findMany: jest.fn().mockResolvedValue([]),
        delete: jest.fn().mockResolvedValue({}),
        deleteMany: jest.fn().mockResolvedValue({ count: 0 }),
      },
    };
    redis = {
      setOtp: jest.fn(),
      hasOtp: jest.fn().mockResolvedValue(true),
      verifyOtp: jest.fn().mockResolvedValue(true),
      deleteOtp: jest.fn(),
      incrementOtpSendCount: jest.fn().mockResolvedValue(1),
      incrementOtpIpCount: jest.fn().mockResolvedValue(1),
      incrementOtpFailCount: jest.fn().mockResolvedValue(1),
      getOtpFailCount: jest.fn().mockResolvedValue(0),
      clearOtpFailCount: jest.fn(),
      blacklistRefreshHash: jest.fn(),
      getBlacklistedFamily: jest.fn().mockResolvedValue(null),
    };
    sms = { send: jest.fn() };
    audit = { log: jest.fn() };
    const fraud = { record: jest.fn() };
    const totp = { issueMfaToken: jest.fn(), verifyChallenge: jest.fn() };
    const anomaly = {
      assessLogin: jest.fn().mockResolvedValue({
        geo: { country: null, lat: null, lng: null },
        deviceIdHash: null,
      }),
      lookupGeo: jest
        .fn()
        .mockReturnValue({ country: null, lat: null, lng: null }),
      hashDeviceId: jest.fn().mockReturnValue(null),
    };
    const metrics = {
      otpSends: { inc: jest.fn() },
      otpFailures: { inc: jest.fn() },
      otpLockouts: { inc: jest.fn() },
      refreshReuse: { inc: jest.fn() },
    };
    const alerts = { record: jest.fn() };

    const module = await Test.createTestingModule({
      providers: [
        AuthService,
        { provide: PrismaService, useValue: prisma },
        { provide: RedisService, useValue: redis },
        { provide: SmsService, useValue: sms },
        { provide: AuditService, useValue: audit },
        { provide: FraudService, useValue: fraud },
        { provide: LoginAnomalyService, useValue: anomaly },
        { provide: MetricsService, useValue: metrics },
        { provide: SecurityAlertsService, useValue: alerts },
        { provide: TotpService, useValue: totp },
        {
          provide: JwtService,
          useValue: new JwtService({
            secret: 'test-secret-test-secret-test-secret!',
          }),
        },
      ],
    }).compile();

    service = module.get(AuthService);
  });

  // ── sendOtp ───────────────────────────────────────────────────

  describe('sendOtp', () => {
    const dto = { phoneNumber: '+9779812345678' };

    it('sends a 6-digit CSPRNG OTP via SMS and stores it', async () => {
      const res = await service.sendOtp(dto, ctx);
      expect(redis.setOtp).toHaveBeenCalledWith(
        dto.phoneNumber,
        expect.stringMatching(/^\d{6}$/),
      );
      expect(sms.send).toHaveBeenCalledTimes(1);
      expect(res.message).toBe('OTP sent successfully');
    });

    it('rejects after the per-phone limit is exceeded', async () => {
      redis.incrementOtpSendCount.mockResolvedValue(4);
      await expect(service.sendOtp(dto, ctx)).rejects.toBeInstanceOf(
        BadRequestException,
      );
      expect(sms.send).not.toHaveBeenCalled();
    });

    it('rejects after the per-IP limit is exceeded (SIM rotation abuse)', async () => {
      redis.incrementOtpIpCount.mockResolvedValue(11);
      await expect(service.sendOtp(dto, ctx)).rejects.toBeInstanceOf(
        BadRequestException,
      );
      expect(redis.setOtp).not.toHaveBeenCalled();
      expect(sms.send).not.toHaveBeenCalled();
    });
  });

  // ── verifyOtp ─────────────────────────────────────────────────

  describe('verifyOtp', () => {
    const dto = { phoneNumber: '+9779812345678', otp: '123456' };

    it('locks out after too many failed attempts and audits the event', async () => {
      redis.getOtpFailCount.mockResolvedValue(5);
      await expect(service.verifyOtp(dto, ctx)).rejects.toBeInstanceOf(
        BadRequestException,
      );
      expect(audit.log).toHaveBeenCalledWith(
        'anonymous',
        'auth.otp_lockout',
        'phone',
        undefined,
        expect.objectContaining({ ip: ctx.ip }),
      );
    });

    it('rejects when no OTP is pending', async () => {
      redis.hasOtp.mockResolvedValue(false);
      await expect(service.verifyOtp(dto, ctx)).rejects.toBeInstanceOf(
        BadRequestException,
      );
    });

    it('rejects a wrong OTP and increments the fail counter', async () => {
      redis.verifyOtp.mockResolvedValue(false);
      await expect(service.verifyOtp(dto, ctx)).rejects.toBeInstanceOf(
        BadRequestException,
      );
      expect(redis.incrementOtpFailCount).toHaveBeenCalledWith(dto.phoneNumber);
    });

    it('creates a new user, deletes the OTP (single use) and issues tokens', async () => {
      prisma.user.findUnique.mockResolvedValue(null);
      prisma.user.create.mockResolvedValue({ ...activeUser });

      const res = await service.verifyOtp(dto, ctx);

      expect(redis.deleteOtp).toHaveBeenCalledWith(dto.phoneNumber);
      expect(res.isNewUser).toBe(true);
      expect(res.accessToken).toEqual(expect.any(String));
      expect(res.refreshToken).toEqual(expect.any(String));
      // Session persisted with a hash, never the raw token.
      const created = prisma.authSession.create.mock.calls[0][0].data;
      expect(created.tokenHash).toMatch(/^[0-9a-f]{64}$/);
      expect(created.tokenHash).not.toBe(res.refreshToken);
      expect(audit.log).toHaveBeenCalledWith(
        activeUser.id,
        'auth.login',
        'user',
        activeUser.id,
        expect.objectContaining({ isNewUser: true }),
      );
    });

    it('blocks suspended accounts (admin-deactivated)', async () => {
      prisma.user.findUnique.mockResolvedValue({
        ...activeUser,
        isActive: false,
        deletionRequestedAt: null,
      });
      await expect(service.verifyOtp(dto, ctx)).rejects.toBeInstanceOf(
        ForbiddenException,
      );
    });

    it('reactivates an account inside the deletion grace period', async () => {
      prisma.user.findUnique.mockResolvedValue({
        ...activeUser,
        isActive: false,
        deletionRequestedAt: new Date(),
      });
      prisma.user.update.mockResolvedValue({ ...activeUser });

      const res = await service.verifyOtp(dto, ctx);
      expect(prisma.user.update).toHaveBeenCalledWith(
        expect.objectContaining({
          data: { deletionRequestedAt: null, isActive: true },
        }),
      );
      expect(res.isNewUser).toBe(false);
    });

    it('evicts the oldest sessions beyond the concurrent-session cap', async () => {
      prisma.user.findUnique.mockResolvedValue({ ...activeUser });
      prisma.authSession.findMany.mockResolvedValue([
        { id: 'old-1', tokenHash: 'h1', familyId: 'f1' },
      ]);

      await service.verifyOtp(dto, ctx);

      expect(prisma.authSession.deleteMany).toHaveBeenCalledWith({
        where: { id: { in: ['old-1'] } },
      });
      expect(redis.blacklistRefreshHash).toHaveBeenCalledWith(
        'h1',
        'f1',
        appConfig.refreshTokenTtlSeconds,
      );
    });
  });

  // ── refresh ───────────────────────────────────────────────────

  describe('refresh', () => {
    const validSession = {
      id: 'sess-1',
      userId: activeUser.id,
      familyId: 'fam-1',
      tokenHash: 'ignored',
      expiresAt: new Date(Date.now() + 86_400_000),
    };

    it('rotates: retires old session, blacklists hash, issues new pair in same family', async () => {
      prisma.authSession.findUnique.mockResolvedValue(validSession);
      prisma.user.findUnique.mockResolvedValue({ ...activeUser });

      const res = await service.refresh('some-refresh-token', ctx);

      expect(prisma.authSession.delete).toHaveBeenCalledWith({
        where: { id: 'sess-1' },
      });
      expect(redis.blacklistRefreshHash).toHaveBeenCalledWith(
        expect.stringMatching(/^[0-9a-f]{64}$/),
        'fam-1',
        appConfig.refreshTokenTtlSeconds,
      );
      const created = prisma.authSession.create.mock.calls[0][0].data;
      expect(created.familyId).toBe('fam-1'); // lineage preserved
      expect(res.accessToken).toEqual(expect.any(String));
      expect(res.refreshToken).toEqual(expect.any(String));
    });

    it('revokes the ENTIRE family when a rotated token is reused (theft response)', async () => {
      redis.getBlacklistedFamily.mockResolvedValue('fam-stolen');
      prisma.authSession.findMany.mockResolvedValue([
        { id: 's1', userId: activeUser.id, tokenHash: 'h1' },
        { id: 's2', userId: activeUser.id, tokenHash: 'h2' },
      ]);

      await expect(service.refresh('stolen-token', ctx)).rejects.toBeInstanceOf(
        UnauthorizedException,
      );

      expect(prisma.authSession.deleteMany).toHaveBeenCalledWith({
        where: { familyId: 'fam-stolen' },
      });
      expect(redis.blacklistRefreshHash).toHaveBeenCalledTimes(2);
      expect(audit.log).toHaveBeenCalledWith(
        activeUser.id,
        'auth.refresh_reuse_detected',
        'user',
        activeUser.id,
        expect.objectContaining({ familyId: 'fam-stolen' }),
      );
    });

    it('rejects unknown tokens with a generic error', async () => {
      prisma.authSession.findUnique.mockResolvedValue(null);
      await expect(service.refresh('bogus', ctx)).rejects.toThrow(
        'Invalid or expired refresh token',
      );
    });

    it('rejects expired sessions', async () => {
      prisma.authSession.findUnique.mockResolvedValue({
        ...validSession,
        expiresAt: new Date(Date.now() - 1000),
      });
      await expect(service.refresh('expired', ctx)).rejects.toBeInstanceOf(
        UnauthorizedException,
      );
    });

    it('rejects tokens of deactivated users with the same generic error', async () => {
      prisma.authSession.findUnique.mockResolvedValue(validSession);
      prisma.user.findUnique.mockResolvedValue({
        ...activeUser,
        isActive: false,
      });
      await expect(service.refresh('token', ctx)).rejects.toThrow(
        'Invalid or expired refresh token',
      );
    });
  });

  // ── logout / sessions ─────────────────────────────────────────

  describe('logout & session management', () => {
    it('logout deletes the session and blacklists its hash', async () => {
      prisma.authSession.findUnique.mockResolvedValue({
        id: 'sess-1',
        familyId: 'fam-1',
      });
      const res = await service.logout('token');
      expect(prisma.authSession.delete).toHaveBeenCalledWith({
        where: { id: 'sess-1' },
      });
      expect(redis.blacklistRefreshHash).toHaveBeenCalled();
      expect(res.message).toBe('Logged out successfully');
    });

    it('logout with an unknown token returns the same response (no oracle)', async () => {
      prisma.authSession.findUnique.mockResolvedValue(null);
      const res = await service.logout('unknown');
      expect(res.message).toBe('Logged out successfully');
      expect(redis.blacklistRefreshHash).not.toHaveBeenCalled();
    });

    it('logoutAll revokes and blacklists every session', async () => {
      prisma.authSession.findMany.mockResolvedValue([
        { tokenHash: 'h1', familyId: 'f1' },
        { tokenHash: 'h2', familyId: 'f2' },
      ]);
      const res = await service.logoutAll(activeUser.id);
      expect(prisma.authSession.deleteMany).toHaveBeenCalledWith({
        where: { userId: activeUser.id },
      });
      expect(redis.blacklistRefreshHash).toHaveBeenCalledTimes(2);
      expect(res.count).toBe(2);
      expect(audit.log).toHaveBeenCalledWith(
        activeUser.id,
        'auth.logout_all',
        'user',
        activeUser.id,
        { sessionsRevoked: 2 },
      );
    });

    it('revokeSession enforces ownership (no cross-user revocation)', async () => {
      prisma.authSession.findFirst.mockResolvedValue(null);
      await expect(
        service.revokeSession('attacker-id', 'victims-session'),
      ).rejects.toThrow('Session not found');
      expect(prisma.authSession.findFirst).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: 'victims-session', userId: 'attacker-id' },
        }),
      );
    });

    it('revokeSession deletes and blacklists an owned session', async () => {
      prisma.authSession.findFirst.mockResolvedValue({
        id: 'sess-9',
        tokenHash: 'h9',
        familyId: 'f9',
      });
      const res = await service.revokeSession(activeUser.id, 'sess-9');
      expect(prisma.authSession.delete).toHaveBeenCalledWith({
        where: { id: 'sess-9' },
      });
      expect(redis.blacklistRefreshHash).toHaveBeenCalledWith(
        'h9',
        'f9',
        appConfig.refreshTokenTtlSeconds,
      );
      expect(res.message).toBe('Session revoked');
    });
  });
});
