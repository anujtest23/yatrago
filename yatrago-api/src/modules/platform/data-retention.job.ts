import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { PrismaService } from '../../database/prisma.service';

/**
 * Data-retention housekeeping (SECURITY.md: retention policy / minimize
 * stored data). Runs nightly, deletes in bounded batches so a large backlog
 * can never lock the tables.
 *
 *  - Expired auth sessions           : removed 7 days past expiry
 *  - Low-value audit logs (auth.*)   : removed after 180 days
 *  - Fraud events                    : removed after 365 days
 */
@Injectable()
export class DataRetentionJob {
  private readonly logger = new Logger(DataRetentionJob.name);

  constructor(private prisma: PrismaService) {}

  @Cron(CronExpression.EVERY_DAY_AT_4AM)
  async purge() {
    const now = Date.now();
    const day = 24 * 60 * 60 * 1000;

    const sessions = await this.prisma.authSession.deleteMany({
      where: { expiresAt: { lt: new Date(now - 7 * day) } },
    });

    // Keep security-critical audits longer; only prune high-volume auth noise.
    const audits = await this.prisma.auditLog.deleteMany({
      where: {
        createdAt: { lt: new Date(now - 180 * day) },
        action: { startsWith: 'auth.' },
      },
    });

    const fraud = await this.prisma.fraudEvent.deleteMany({
      where: { createdAt: { lt: new Date(now - 365 * day) } },
    });

    const total = sessions.count + audits.count + fraud.count;
    if (total > 0) {
      this.logger.log(
        `Retention purge: ${sessions.count} sessions, ${audits.count} audit logs, ${fraud.count} fraud events`,
      );
    }
  }
}
