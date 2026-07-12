import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { randomUUID } from 'crypto';
import { PrismaService } from '../../database/prisma.service';
import { AuditService } from '../platform/audit.service';
import { FraudService } from '../platform/fraud.service';
import { EsewaService } from './esewa.service';
import { appConfig } from '../../config/app.config';
import type { WalletTopup } from '@prisma/client';

/**
 * Orchestrates self-service wallet top-ups through the eSewa gateway.
 *
 * Trust model: the client can only ever move a top-up FORWARD by asking us to
 * re-check with eSewa. It can never assert success. Crediting is:
 *   1. gated on a server-to-server status query returning COMPLETE,
 *   2. gated on the amount eSewa reports matching what we signed,
 *   3. performed exactly once via an atomic status transition guarded by a
 *      conditional UPDATE + a unique provider-ref (double-credit impossible).
 *
 * Reconciliation (G1): the same verified-credit path is reachable from three
 * triggers — the in-session verify, an app-driven reconcile (wallet/top-up
 * open + app resume), and a periodic cron — so a payment that settled while the
 * app was closed is still credited. Every trigger funnels through
 * {@link reconcileOne} → {@link creditOnce}; concurrency and replay are
 * resolved by the conditional status flip, so no trigger can double-credit.
 */
@Injectable()
export class PaymentsService {
  private readonly logger = new Logger(PaymentsService.name);
  private readonly cfg = appConfig.esewa;

  constructor(
    private prisma: PrismaService,
    private esewa: EsewaService,
    private fraud: FraudService,
    private audit: AuditService,
  ) {}

  /** The payment methods a driver can top up with. */
  getPaymentMethods() {
    // For now only the eSewa sandbox is wired up. Saved bank accounts / cards /
    // other wallets will be appended here as they are implemented.
    return {
      methods: [
        {
          id: 'esewa',
          type: 'wallet',
          provider: 'esewa',
          label: 'eSewa',
          subtitle: 'Pay with your eSewa account',
          environment: this.cfg.productCode === 'EPAYTEST' ? 'sandbox' : 'live',
          enabled: true,
          minAmount: this.cfg.minAmount,
          maxAmount: this.cfg.maxAmount,
        },
      ],
      // No saved instruments yet; the app shows "Add payment method" when empty.
      saved: [],
    };
  }

  /**
   * Create a top-up intent and return a fully-signed eSewa form for the app to
   * POST from an in-app WebView. No money moves here.
   */
  async initiateEsewa(userId: string, amount: number, ipAddress?: string) {
    // Whole rupees only, within configured guardrails. (DTO also validates,
    // this is defence in depth against a bypassed client.)
    if (!Number.isInteger(amount)) {
      throw new BadRequestException('Amount must be a whole number of rupees');
    }
    if (amount < this.cfg.minAmount || amount > this.cfg.maxAmount) {
      throw new BadRequestException(
        `Top-up must be between NPR ${this.cfg.minAmount} and NPR ${this.cfg.maxAmount}`,
      );
    }

    // One live intent at a time keeps the reconciliation surface small and
    // stops a client spamming half-finished payments.
    const active = await this.prisma.walletTopup.findFirst({
      where: { userId, status: { in: ['initiated', 'pending'] } },
      orderBy: { createdAt: 'desc' },
    });
    if (active && !this.isExpired(active.createdAt)) {
      // Hand back the existing intent's fresh form rather than creating a new
      // row, so a retap doesn't leak orphan intents.
      const { gatewayUrl, fields } = this.esewa.buildForm({
        amount: active.amount,
        transactionUuid: active.transactionUuid,
      });
      return {
        paymentId: active.id,
        transactionUuid: active.transactionUuid,
        gatewayUrl,
        fields,
        successUrl: this.cfg.successUrl,
        failureUrl: this.cfg.failureUrl,
      };
    }
    if (active && this.isExpired(active.createdAt)) {
      // Only expire without a provider check when the client is asking for a
      // brand-new intent — a stale, never-completed one. The verify/reconcile
      // paths always ask eSewa before expiring (see reconcileOne).
      await this.prisma.walletTopup.updateMany({
        where: { id: active.id, status: { in: ['initiated', 'pending'] } },
        data: { status: 'expired' },
      });
    }

    // Rate limit: cap intents/day (fraud signal + abuse brake).
    const since = new Date(Date.now() - 24 * 3600_000);
    const todayCount = await this.prisma.walletTopup.count({
      where: { userId, createdAt: { gte: since } },
    });
    if (todayCount >= 20) {
      await this.fraud.record(userId, 'topup_intent_spam', 10, {
        intentsLast24h: todayCount,
      });
      throw new BadRequestException(
        'Too many top-up attempts today. Please try again later.',
      );
    }

    const transactionUuid = randomUUID();
    const topup = await this.prisma.walletTopup.create({
      data: {
        userId,
        provider: 'esewa',
        amount,
        totalAmount: amount,
        status: 'initiated',
        transactionUuid,
        ipAddress,
      },
    });

    await this.audit.log(userId, 'topup.initiated', 'wallet_topup', topup.id, {
      amount,
      provider: 'esewa',
    });

    const { gatewayUrl, fields } = this.esewa.buildForm({
      amount,
      transactionUuid,
    });
    return {
      paymentId: topup.id,
      transactionUuid,
      gatewayUrl,
      fields,
      successUrl: this.cfg.successUrl,
      failureUrl: this.cfg.failureUrl,
    };
  }

  /**
   * Re-verify a single top-up against eSewa and credit the wallet if (and only
   * if) it genuinely settled. Called by the user after the WebView returns.
   * Idempotent: safe to call repeatedly / concurrently.
   */
  async verifyEsewa(userId: string, paymentId: string) {
    const topup = await this.prisma.walletTopup.findUnique({
      where: { id: paymentId },
    });
    // IDOR guard: a user may only verify their OWN intent. Unknown id and
    // someone else's id are indistinguishable to the caller.
    if (!topup || topup.userId !== userId) {
      throw new NotFoundException('Top-up not found');
    }

    // Terminal states short-circuit (idempotent replay).
    if (topup.status === 'completed') {
      const balance = await this.currentBalance(userId);
      return { status: 'completed', amount: topup.amount, balance };
    }
    if (
      topup.status === 'failed' ||
      topup.status === 'expired' ||
      topup.status === 'refunded'
    ) {
      return { status: topup.status, amount: topup.amount };
    }

    // Eager: this is a foreground verify, so a provider "not found / cancelled"
    // is a real, immediate failure worth reporting to the user now.
    return this.reconcileOne(topup, { eager: true });
  }

  /**
   * Reconcile every non-terminal intent belonging to a user. Triggered by the
   * app when the wallet / top-up screen opens or the app resumes from the
   * background — so a payment that settled while the app was gone is credited
   * without the client needing to remember the paymentId.
   */
  async reconcileUserPending(userId: string) {
    const rows = await this.prisma.walletTopup.findMany({
      where: { userId, status: { in: ['initiated', 'pending'] } },
      orderBy: { createdAt: 'asc' },
    });

    let credited = 0;
    for (const row of rows) {
      try {
        const res = await this.reconcileOne(row, { eager: false });
        if (res.status === 'completed') credited++;
      } catch (err) {
        // Provider hiccup on one intent must not abort the rest; it will be
        // retried on the next trigger / cron cycle.
        this.logger.warn(
          `reconcileUserPending: ${row.id} failed: ${(err as Error).message}`,
        );
      }
    }

    const balance = await this.currentBalance(userId);
    return { balance, checked: rows.length, credited };
  }

  /**
   * Background sweep for the reconciliation cron. Re-checks non-terminal
   * intents that are old enough that the in-session verify has had its chance,
   * and (for refund detection) recently-completed intents. Batched + sequential
   * to avoid hammering the provider. Never throws for a single bad row.
   */
  async reconcileStale(limit = 100): Promise<{
    pendingChecked: number;
    credited: number;
    refundChecked: number;
    refunded: number;
  }> {
    // Give the foreground verify ~2 minutes before the cron touches an intent.
    const cutoff = new Date(Date.now() - 2 * 60_000);
    const pending = await this.prisma.walletTopup.findMany({
      where: {
        status: { in: ['initiated', 'pending'] },
        createdAt: { lt: cutoff },
      },
      orderBy: { createdAt: 'asc' },
      take: limit,
    });

    let credited = 0;
    for (const row of pending) {
      try {
        const res = await this.reconcileOne(row, { eager: false });
        if (res.status === 'completed') credited++;
      } catch (err) {
        this.logger.warn(
          `reconcileStale(pending): ${row.id} failed: ${(err as Error).message}`,
        );
      }
    }

    // G3: refund sweep over recently-completed intents.
    const refundResult = await this.reconcileRefunds(limit);

    return {
      pendingChecked: pending.length,
      credited,
      refundChecked: refundResult.checked,
      refunded: refundResult.refunded,
    };
  }

  /**
   * G2 — Top-up attempt history (all statuses), cursor-paginated and DESC by
   * creation. Distinct from the wallet transaction ledger: this shows payment
   * *attempts* (pending / completed / failed / expired / refunded), so a driver
   * can tell an in-progress or failed top-up apart from a settled credit.
   */
  async getTopupHistory(userId: string, limit = 20, cursor?: string) {
    const take = Math.min(Math.max(limit, 1), 50);
    const rows = await this.prisma.walletTopup.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: take + 1,
      ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
    });
    const hasMore = rows.length > take;
    const items = hasMore ? rows.slice(0, take) : rows;
    return {
      topups: items.map((t) => ({
        id: t.id,
        amount: t.amount,
        status: t.status,
        provider: t.provider,
        providerRef: t.providerRef,
        createdAt: t.createdAt,
        completedAt: t.completedAt,
        refundedAmount: t.refundedAmount,
        refundedAt: t.refundedAt,
      })),
      nextCursor: hasMore ? items[items.length - 1].id : null,
    };
  }

  /**
   * The single verified-credit core, shared by verify + reconcile. The intent
   * passed in is non-terminal (initiated | pending).
   *
   * Expiry safety (G1): we ALWAYS ask eSewa before giving up on an intent, so
   * a payment that settled just before our TTL is credited rather than being
   * blind-expired and lost.
   *
   * @param eager foreground verify — a non-complete provider status becomes a
   *              terminal failure immediately. Background reconcile (eager=false)
   *              only fails/expires once the intent is past its TTL, so an intent
   *              the user is still mid-paying is left to re-check next cycle.
   */
  private async reconcileOne(
    topup: WalletTopup,
    opts: { eager: boolean },
  ): Promise<{ status: string; amount: number; balance?: number }> {
    const result = await this.esewa.queryStatus({
      transactionUuid: topup.transactionUuid,
      totalAmount: topup.totalAmount,
    });

    if (result.status === 'COMPLETE') {
      // Tamper check: eSewa must have charged exactly what we signed.
      if (
        result.totalAmount != null &&
        Math.round(result.totalAmount) !== Math.round(topup.totalAmount)
      ) {
        await this.fraud.record(topup.userId, 'topup_amount_mismatch', 40, {
          expected: topup.totalAmount,
          reported: result.totalAmount,
          paymentId: topup.id,
        });
        await this.prisma.walletTopup.updateMany({
          where: { id: topup.id, status: { in: ['initiated', 'pending'] } },
          data: { status: 'failed' },
        });
        throw new BadRequestException(
          'Payment amount mismatch. This top-up was not credited.',
        );
      }

      const balance = await this.creditOnce(
        topup.id,
        topup.userId,
        topup.amount,
        result.refId,
      );
      return { status: 'completed', amount: topup.amount, balance };
    }

    if (result.status === 'PENDING') {
      // Still settling at the provider — keep it open regardless of TTL so we
      // never abandon a payment the provider itself says is in progress.
      await this.prisma.walletTopup.updateMany({
        where: { id: topup.id, status: 'initiated' },
        data: { status: 'pending' },
      });
      return { status: 'pending', amount: topup.amount };
    }

    // Provider says not complete and not pending (CANCELED / NOT_FOUND /
    // AMBIGUOUS / refund). Only mark terminal when it is safe to do so.
    const expired = this.isExpired(topup.createdAt);
    if (opts.eager || expired) {
      await this.prisma.walletTopup.updateMany({
        where: { id: topup.id, status: { in: ['initiated', 'pending'] } },
        data: { status: expired ? 'expired' : 'failed' },
      });
      return { status: expired ? 'expired' : 'failed', amount: topup.amount };
    }

    // Within TTL and not eager: the user may still be completing payment.
    // Leave the row untouched for the next reconcile cycle.
    return { status: topup.status, amount: topup.amount };
  }

  /**
   * G3 — Refund reconciliation. Scans recently-completed top-ups and, if eSewa
   * now reports a refund, applies a compensating debit. Balances are never
   * silently changed: every reversal writes a WalletTransaction + audit entry,
   * and ambiguous partial refunds are flagged for manual review instead of
   * guessing an amount.
   */
  private async reconcileRefunds(
    limit = 100,
  ): Promise<{ checked: number; refunded: number }> {
    // Only look back a bounded window; older settlements are out of dispute.
    const since = new Date(Date.now() - 7 * 24 * 3600_000);
    const rows = await this.prisma.walletTopup.findMany({
      where: {
        status: 'completed',
        completedAt: { gte: since },
      },
      orderBy: { completedAt: 'asc' },
      take: limit,
    });

    let refunded = 0;
    for (const row of rows) {
      try {
        const result = await this.esewa.queryStatus({
          transactionUuid: row.transactionUuid,
          totalAmount: row.totalAmount,
        });
        if (
          result.status === 'FULL_REFUND' ||
          result.status === 'PARTIAL_REFUND'
        ) {
          const did = await this.applyRefund(row, result.status);
          if (did) refunded++;
        }
      } catch (err) {
        this.logger.warn(
          `reconcileRefunds: ${row.id} failed: ${(err as Error).message}`,
        );
      }
    }
    return { checked: rows.length, refunded };
  }

  /**
   * Apply a compensating debit for a refunded top-up. Idempotent: a partial
   * refund that grows is topped up by the delta only, and a fully-reversed
   * top-up is never reversed twice.
   *
   * Business rule: full refunds reverse the full credited amount even if that
   * drives the wallet negative (the money genuinely left the provider), and the
   * negative balance blocks further spend via the existing debit guard until
   * corrected. Partial refunds whose exact amount cannot be derived from the
   * provider are NOT auto-applied — they are flagged for manual review.
   */
  private async applyRefund(
    topup: WalletTopup,
    kind: 'FULL_REFUND' | 'PARTIAL_REFUND',
  ): Promise<boolean> {
    if (kind === 'PARTIAL_REFUND') {
      // eSewa's status API does not give us a reliable refunded amount for
      // partials; do not guess. Record for manual review, once.
      await this.audit.log(
        topup.userId,
        'topup.refund_partial_review',
        'wallet_topup',
        topup.id,
        { note: 'Partial refund reported; manual review required.' },
      );
      await this.fraud.record(topup.userId, 'topup_partial_refund', 20, {
        paymentId: topup.id,
      });
      return false;
    }

    return this.prisma.$transaction(async (tx) => {
      // Re-read under the transaction and only act if not already reversed.
      const fresh = await tx.walletTopup.findUnique({
        where: { id: topup.id },
      });
      if (!fresh || fresh.status === 'refunded' || fresh.refundedAmount != null) {
        return false;
      }

      const wallet = await tx.wallet.upsert({
        where: { userId: fresh.userId },
        create: { userId: fresh.userId },
        update: {},
      });

      // Compensating debit — raw decrement so the reversal always records even
      // if the balance was already spent down (may go negative by design).
      const updated = await tx.wallet.update({
        where: { id: wallet.id },
        data: { balance: { decrement: fresh.amount } },
      });
      const txn = await tx.walletTransaction.create({
        data: {
          walletId: wallet.id,
          type: 'debit',
          amount: fresh.amount,
          source: 'refund_reversal',
          reference: fresh.providerRef ?? fresh.id,
          note: 'Reversal of refunded eSewa top-up',
        },
      });
      await tx.walletTopup.update({
        where: { id: fresh.id },
        data: {
          status: 'refunded',
          refundedAmount: fresh.amount,
          refundedAt: new Date(),
        },
      });

      await this.audit.log(
        fresh.userId,
        'topup.refunded',
        'wallet_topup',
        fresh.id,
        {
          amount: fresh.amount,
          walletTxnId: txn.id,
          balanceAfter: updated.balance,
        },
      );
      if (updated.balance < 0) {
        await this.fraud.record(fresh.userId, 'wallet_negative_after_refund', 30, {
          paymentId: fresh.id,
          balance: updated.balance,
        });
      }
      return true;
    });
  }

  /**
   * Atomically flip the intent to `completed` and credit the wallet exactly
   * once. The conditional UPDATE is the concurrency gate: only the caller that
   * wins the transition (count === 1) performs the credit; everyone else reads
   * the already-completed row. The unique `providerRef` is the DB backstop.
   */
  private async creditOnce(
    topupId: string,
    userId: string,
    amount: number,
    providerRef?: string,
  ): Promise<number> {
    return this.prisma.$transaction(async (tx) => {
      const flipped = await tx.walletTopup.updateMany({
        where: { id: topupId, status: { in: ['initiated', 'pending'] } },
        data: {
          status: 'completed',
          providerRef: providerRef ?? null,
          completedAt: new Date(),
        },
      });

      const wallet = await tx.wallet.upsert({
        where: { userId },
        create: { userId },
        update: {},
      });

      if (flipped.count === 0) {
        // Lost the race — already credited by a concurrent verify. Do NOT
        // credit again; just report the current balance.
        return wallet.balance;
      }

      const updatedWallet = await tx.wallet.update({
        where: { id: wallet.id },
        data: { balance: { increment: amount } },
      });
      const txn = await tx.walletTransaction.create({
        data: {
          walletId: wallet.id,
          type: 'credit',
          amount,
          source: 'topup',
          reference: providerRef ?? topupId,
          note: 'Wallet top-up via eSewa',
        },
      });
      await tx.walletTopup.update({
        where: { id: topupId },
        data: { creditedTxnId: txn.id },
      });

      await this.audit.log(userId, 'topup.credited', 'wallet_topup', topupId, {
        amount,
        providerRef,
        walletTxnId: txn.id,
      });

      return updatedWallet.balance;
    });
  }

  private async currentBalance(userId: string): Promise<number> {
    const wallet = await this.prisma.wallet.findUnique({ where: { userId } });
    return wallet?.balance ?? 0;
  }

  private isExpired(createdAt: Date): boolean {
    const ageMs = Date.now() - createdAt.getTime();
    return ageMs > this.cfg.intentTtlMinutes * 60_000;
  }
}
