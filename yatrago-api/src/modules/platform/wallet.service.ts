import { BadRequestException, Injectable } from '@nestjs/common';
import { PrismaService } from '../../database/prisma.service';

@Injectable()
export class WalletService {
  constructor(private prisma: PrismaService) {}

  // Get or lazily create the user's wallet
  async getOrCreate(userId: string) {
    return this.prisma.wallet.upsert({
      where: { userId },
      create: { userId },
      update: {},
    });
  }

  async credit(
    userId: string,
    amount: number,
    source: string,
    reference?: string,
    note?: string,
  ) {
    if (amount <= 0) throw new BadRequestException('Credit amount must be positive');
    const wallet = await this.getOrCreate(userId);

    return this.prisma.$transaction(async (tx) => {
      await tx.wallet.update({
        where: { id: wallet.id },
        data: { balance: { increment: amount } },
      });
      return tx.walletTransaction.create({
        data: { walletId: wallet.id, type: 'credit', amount, source, reference, note },
      });
    });
  }

  async debit(
    userId: string,
    amount: number,
    source: string,
    reference?: string,
    note?: string,
  ) {
    if (amount <= 0) throw new BadRequestException('Debit amount must be positive');
    const wallet = await this.getOrCreate(userId);

    return this.prisma.$transaction(async (tx) => {
      // Conditional decrement guards against concurrent overdraw
      const updated = await tx.wallet.updateMany({
        where: { id: wallet.id, balance: { gte: amount } },
        data: { balance: { decrement: amount } },
      });
      if (updated.count === 0) {
        throw new BadRequestException('Insufficient wallet balance');
      }
      return tx.walletTransaction.create({
        data: { walletId: wallet.id, type: 'debit', amount, source, reference, note },
      });
    });
  }

  async getBalance(userId: string) {
    const wallet = await this.getOrCreate(userId);
    const transactions = await this.prisma.walletTransaction.findMany({
      where: { walletId: wallet.id },
      orderBy: { createdAt: 'desc' },
      take: 50,
    });
    return { balance: wallet.balance, transactions };
  }

  // Instant recorded top-up. Real PSP money-in is out of scope (passenger
  // gateways were removed); this is the seam a future gateway callback hooks.
  async topUp(userId: string, amount: number) {
    await this.credit(userId, amount, 'topup', undefined, 'Wallet top-up');
    const wallet = await this.getOrCreate(userId);
    return { balance: wallet.balance };
  }

  // Guard used before posting a ride / accepting a booking.
  async assertMinBalance(userId: string, min: number) {
    const wallet = await this.getOrCreate(userId);
    if (wallet.balance < min) {
      throw new BadRequestException(
        `Insufficient wallet balance. Maintain at least NPR ${min} to continue. Please top up your wallet.`,
      );
    }
  }

  // Driver commission deduction history.
  async getCommissions(userId: string) {
    const driver = await this.prisma.driverProfile.findUnique({
      where: { userId },
    });
    if (!driver) return { commissions: [] };
    const commissions = await this.prisma.commissionRecord.findMany({
      where: { driverId: driver.id },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
    return { commissions };
  }
}
