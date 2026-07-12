import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { PaymentsService } from './payments.service';

/**
 * Periodic safety net (G1) for wallet top-ups. Even though the app reconciles
 * on open/resume, a driver who paid and never reopened the app would otherwise
 * wait indefinitely for their credit. This sweep re-checks every stale
 * `initiated`/`pending` intent with eSewa (and recently-completed ones for
 * refunds) and credits/expires/reverses accordingly.
 *
 * Safety: it calls the exact same verified-credit path as the foreground
 * verify, so it is idempotent by construction and can never double-credit.
 */
@Injectable()
export class PaymentsReconciliationJob {
  private readonly logger = new Logger(PaymentsReconciliationJob.name);
  private running = false;

  constructor(private readonly payments: PaymentsService) {}

  @Cron(CronExpression.EVERY_5_MINUTES)
  async reconcile(): Promise<void> {
    // Guard against overlap if a sweep runs long (many pending intents).
    if (this.running) {
      this.logger.warn('Reconciliation still running; skipping this tick.');
      return;
    }
    this.running = true;
    try {
      const result = await this.payments.reconcileStale(100);
      if (
        result.pendingChecked > 0 ||
        result.credited > 0 ||
        result.refunded > 0
      ) {
        this.logger.log(
          `Reconciliation: checked=${result.pendingChecked} credited=${result.credited} ` +
            `refundChecked=${result.refundChecked} refunded=${result.refunded}`,
        );
      }
    } catch (err) {
      this.logger.error(
        `Reconciliation sweep failed: ${(err as Error).message}`,
      );
    } finally {
      this.running = false;
    }
  }
}
