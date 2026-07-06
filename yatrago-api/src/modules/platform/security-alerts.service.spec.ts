import { Test } from '@nestjs/testing';
import { SecurityAlertsService } from './security-alerts.service';
import { AuditService } from './audit.service';
import { PrismaService } from '../../database/prisma.service';

describe('SecurityAlertsService', () => {
  let service: SecurityAlertsService;
  let prisma: {
    user: { findMany: jest.Mock };
    notification: { createMany: jest.Mock };
  };
  let audit: { log: jest.Mock };

  beforeEach(async () => {
    prisma = {
      user: {
        findMany: jest.fn().mockResolvedValue([{ id: 'admin-1' }]),
      },
      notification: { createMany: jest.fn().mockResolvedValue({ count: 1 }) },
    };
    audit = { log: jest.fn() };

    const module = await Test.createTestingModule({
      providers: [
        SecurityAlertsService,
        { provide: PrismaService, useValue: prisma },
        { provide: AuditService, useValue: audit },
      ],
    }).compile();

    service = module.get(SecurityAlertsService);
  });

  const flush = () => new Promise((r) => setImmediate(r));

  it('stays silent below the threshold', async () => {
    for (let i = 0; i < 9; i++) service.record('otp_lockout');
    await flush();
    expect(prisma.notification.createMany).not.toHaveBeenCalled();
  });

  it('alerts admins when the OTP lockout threshold trips', async () => {
    for (let i = 0; i < 10; i++) service.record('otp_lockout');
    await flush();
    expect(audit.log).toHaveBeenCalledWith(
      'system',
      'security.alert',
      'alert',
      'otp_lockout',
      expect.any(Object),
    );
    expect(prisma.notification.createMany).toHaveBeenCalledTimes(1);
  });

  it('rate-limits alerts to one per window (no ops spam)', async () => {
    for (let i = 0; i < 30; i++) service.record('otp_lockout');
    await flush();
    expect(prisma.notification.createMany).toHaveBeenCalledTimes(1);
  });

  it('ignores unknown event types', async () => {
    for (let i = 0; i < 50; i++) service.record('nonsense_event');
    await flush();
    expect(prisma.notification.createMany).not.toHaveBeenCalled();
  });
});
