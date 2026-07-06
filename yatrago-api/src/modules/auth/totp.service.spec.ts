import { Test } from '@nestjs/testing';
import { BadRequestException, ForbiddenException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { authenticator } from 'otplib';
import { TotpService } from './totp.service';
import { PrismaService } from '../../database/prisma.service';
import { RedisService } from './redis.service';
import { EncryptionService } from '../platform/encryption.service';
import { AuditService } from '../platform/audit.service';

describe('TotpService', () => {
  let service: TotpService;
  let prisma: { user: Record<string, jest.Mock> };
  let redis: Record<string, jest.Mock>;
  const encryption = new EncryptionService();

  beforeEach(async () => {
    prisma = {
      user: {
        findUnique: jest.fn(),
        findUniqueOrThrow: jest.fn(),
        update: jest.fn(),
      },
    };
    redis = {
      getTotpFailCount: jest.fn().mockResolvedValue(0),
      incrementTotpFailCount: jest.fn(),
      clearTotpFailCount: jest.fn(),
    };

    const module = await Test.createTestingModule({
      providers: [
        TotpService,
        { provide: PrismaService, useValue: prisma },
        { provide: RedisService, useValue: redis },
        { provide: EncryptionService, useValue: encryption },
        { provide: AuditService, useValue: { log: jest.fn() } },
        {
          provide: JwtService,
          useValue: new JwtService({
            secret: 'test-secret-test-secret-test-secret!',
          }),
        },
      ],
    }).compile();

    service = module.get(TotpService);
  });

  it('refuses setup for non-privileged users', async () => {
    await expect(service.setup('u1', 'user')).rejects.toBeInstanceOf(
      ForbiddenException,
    );
  });

  it('setup returns a secret + otpauth URL and stores it encrypted', async () => {
    prisma.user.findUniqueOrThrow.mockResolvedValue({
      phoneNumber: '+9779812345678',
      totpEnabledAt: null,
    });

    const res = await service.setup('admin-1', 'admin');
    expect(res.secret).toEqual(expect.any(String));
    expect(res.otpauthUrl).toContain('otpauth://');
    const stored = prisma.user.update.mock.calls[0][0].data.totpSecret;
    expect(stored).toMatch(/^enc:v1:/); // encrypted at rest
  });

  it('enable accepts a valid code and rejects an invalid one', async () => {
    const secret = authenticator.generateSecret();
    prisma.user.findUniqueOrThrow.mockResolvedValue({
      totpSecret: encryption.encrypt(secret),
      totpEnabledAt: null,
    });

    await expect(
      service.enable('admin-1', 'admin', '000000'),
    ).rejects.toBeInstanceOf(BadRequestException);

    const valid = authenticator.generate(secret);
    const res = await service.enable('admin-1', 'admin', valid);
    expect(res.message).toBe('MFA enabled');
  });

  it('verifyChallenge round-trips through a real mfa token', async () => {
    const secret = authenticator.generateSecret();
    const token = service.issueMfaToken('admin-1');
    prisma.user.findUnique.mockResolvedValue({
      id: 'admin-1',
      totpSecret: encryption.encrypt(secret),
      totpEnabledAt: new Date(),
      isActive: true,
    });

    const userId = await service.verifyChallenge(
      token,
      authenticator.generate(secret),
    );
    expect(userId).toBe('admin-1');
  });
});
