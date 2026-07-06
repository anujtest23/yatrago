import { BadRequestException, Injectable } from '@nestjs/common';
import { PrismaService } from '../../database/prisma.service';
import { FraudService } from './fraud.service';

@Injectable()
export class WalletService {
  constructor(
    private prisma: PrismaService,
    private fraud: FraudService,
  ) {}

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
    if (amount <= 0)
      throw new BadRequestException('Credit amount must be positive');
    const wallet = await this.getOrCreate(userId);

    return this.prisma.$transaction(async (tx) => {
      await tx.wallet.update({
        where: { id: wallet.id },
        data: { balance: { increment: amount } },
      });
      return tx.walletTransaction.create({
        data: {
          walletId: wallet.id,
          type: 'credit',
          amount,
          source,
          reference,
          note,
        },
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
    if (amount <= 0)
      throw new BadRequestException('Debit amount must be positive');
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
        data: {
          walletId: wallet.id,
          type: 'debit',
          amount,
          source,
          reference,
          note,
        },
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

  /**
   * Wallet top-ups are requests, never instant self-credits: balance is
   * created only when an admin verifies the off-app payment and approves.
   * (An instant top-up endpoint would let any user mint unlimited money.)
   */
  async requestTopUp(userId: string, amount: number, reference?: string) {
    // One pending request at a time keeps the review queue unambiguous.
    const pending = await this.prisma.topUpRequest.findFirst({
      where: { userId, status: 'pending' },
    });
    if (pending) {
      throw new BadRequestException(
        'You already have a pending top-up request',
      );
    }

    // Churning the review queue (submit → withdraw-by-rejection → resubmit)
    // is a wallet-abuse pattern; humans rarely need >5 requests a day.
    const requestsToday = await this.prisma.topUpRequest.count({
      where: {
        userId,
        createdAt: { gte: new Date(Date.now() - 24 * 3600_000) },
      },
    });
    if (requestsToday >= 5) {
      await this.fraud.record(userId, 'topup_request_spam', 10, {
        requestsLast24h: requestsToday,
      });
      throw new BadRequestException(
        'Too many top-up requests today. Please try again tomorrow.',
      );
    }

    const request = await this.prisma.topUpRequest.create({
      data: { userId, amount, reference },
    });

    return {
      message:
        'Top-up request submitted. Your balance will be updated after verification.',
      request: {
        id: request.id,
        amount: request.amount,
        status: request.status,
        createdAt: request.createdAt,
      },
    };
  }

  async listTopUpRequests(userId: string) {
    const requests = await this.prisma.topUpRequest.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: 50,
      select: {
        id: true,
        amount: true,
        status: true,
        reference: true,
        adminNote: true,
        createdAt: true,
        processedAt: true,
      },
    });
    return { requests };
  }

  /** Admin approval: atomically flips the request and credits the wallet. */
  async approveTopUpRequest(requestId: string, adminId: string) {
    return this.prisma.$transaction(async (tx) => {
      // Conditional update = idempotency: double-clicking approve (or two
      // concurrent admins) can never credit the wallet twice.
      const flipped = await tx.topUpRequest.updateMany({
        where: { id: requestId, status: 'pending' },
        data: {
          status: 'approved',
          processedBy: adminId,
          processedAt: new Date(),
        },
      });
      if (flipped.count === 0) {
        throw new BadRequestException('Request not found or already processed');
      }

      const request = await tx.topUpRequest.findUniqueOrThrow({
        where: { id: requestId },
      });

      const wallet = await tx.wallet.upsert({
        where: { userId: request.userId },
        create: { userId: request.userId },
        update: {},
      });
      await tx.wallet.update({
        where: { id: wallet.id },
        data: { balance: { increment: request.amount } },
      });
      await tx.walletTransaction.create({
        data: {
          walletId: wallet.id,
          type: 'credit',
          amount: request.amount,
          source: 'topup',
          reference: request.id,
          note: 'Top-up request approved',
        },
      });

      return request;
    });
  }

  async rejectTopUpRequest(
    requestId: string,
    adminId: string,
    adminNote?: string,
  ) {
    const flipped = await this.prisma.topUpRequest.updateMany({
      where: { id: requestId, status: 'pending' },
      data: {
        status: 'rejected',
        processedBy: adminId,
        processedAt: new Date(),
        adminNote,
      },
    });
    if (flipped.count === 0) {
      throw new BadRequestException('Request not found or already processed');
    }
    return this.prisma.topUpRequest.findUniqueOrThrow({
      where: { id: requestId },
    });
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
