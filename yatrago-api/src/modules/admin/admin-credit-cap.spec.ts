import { ForbiddenException } from '@nestjs/common';
import { AdminService } from './admin.service';
import { appConfig } from '../../config/app.config';

/**
 * Regression tests for F-3: the admin wallet-credit dual-control gate is
 * enforced on a rolling 24h CUMULATIVE basis, so a non-super admin cannot
 * evade the super-admin threshold by splitting one large credit into many
 * sub-threshold ones.
 */
describe('AdminService.creditWallet cumulative dual-control', () => {
  const THRESHOLD = appConfig.adminCreditSuperThreshold; // 10_000 by default
  const ADMIN = 'admin-1';
  const TARGET = 'user-1';

  function buildService(priorCreditsLast24h: number[]) {
    const prisma = {
      user: { findUnique: jest.fn().mockResolvedValue({ id: TARGET }) },
      auditLog: {
        findMany: jest
          .fn()
          .mockResolvedValue(
            priorCreditsLast24h.map((amount) => ({ details: { amount } })),
          ),
      },
    };
    const wallet = {
      credit: jest.fn().mockResolvedValue(undefined),
      getBalance: jest.fn().mockResolvedValue({ balance: 0 }),
    };
    const notifications = {
      createNotification: jest.fn().mockResolvedValue(undefined),
    };
    const audit = { log: jest.fn().mockResolvedValue(undefined) };
    const svc = new AdminService(
      prisma as any,
      audit as any,
      wallet as any,
      {} as any,
      notifications as any,
      {} as any,
      {} as any,
    );
    return { svc, wallet };
  }

  it('allows a sub-threshold credit when nothing was credited today', async () => {
    const { svc, wallet } = buildService([]);
    await svc.creditWallet(ADMIN, 'admin', TARGET, { amount: THRESHOLD - 1 });
    expect(wallet.credit).toHaveBeenCalledTimes(1);
  });

  it('blocks a single credit above the threshold for a non-super admin', async () => {
    const { svc, wallet } = buildService([]);
    await expect(
      svc.creditWallet(ADMIN, 'admin', TARGET, { amount: THRESHOLD + 1 }),
    ).rejects.toBeInstanceOf(ForbiddenException);
    expect(wallet.credit).not.toHaveBeenCalled();
  });

  it('blocks split sub-threshold credits that cumulatively exceed the threshold', async () => {
    // Already credited THRESHOLD-1 today; a further sub-threshold credit tips over.
    const { svc, wallet } = buildService([THRESHOLD - 1]);
    await expect(
      svc.creditWallet(ADMIN, 'admin', TARGET, { amount: 100 }),
    ).rejects.toBeInstanceOf(ForbiddenException);
    expect(wallet.credit).not.toHaveBeenCalled();
  });

  it('allows a super admin to exceed the threshold', async () => {
    const { svc, wallet } = buildService([THRESHOLD * 10]);
    await svc.creditWallet(ADMIN, 'super_admin', TARGET, {
      amount: THRESHOLD * 5,
    });
    expect(wallet.credit).toHaveBeenCalledTimes(1);
  });
});
