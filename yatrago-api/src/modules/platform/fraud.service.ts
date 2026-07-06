import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../../database/prisma.service';
import { AuditService } from './audit.service';
import { MetricsService } from './metrics.service';
import { SecurityAlertsService } from './security-alerts.service';

/**
 * Fraud-scoring foundation (SECURITY.md). Events add to a cumulative
 * per-user score; crossing thresholds triggers automatic responses:
 *
 *   ≥ WARN (50)     → in-app warning notification (once per crossing)
 *   ≥ SUSPEND (80)  → account deactivated + sessions revoked (regular
 *                     users only — admin accounts are never auto-suspended,
 *                     preventing a lock-out attack on operations staff)
 *
 * Recording is fire-and-forget from callers' perspective: a fraud-ledger
 * failure must never break the main action.
 */
@Injectable()
export class FraudService {
  private readonly logger = new Logger(FraudService.name);

  static readonly WARN_THRESHOLD = 50;
  static readonly SUSPEND_THRESHOLD = 80;

  constructor(
    private prisma: PrismaService,
    private audit: AuditService,
    private metrics: MetricsService,
    private alerts: SecurityAlertsService,
  ) {}

  async record(
    userId: string,
    type: string,
    score: number,
    details?: Record<string, unknown>,
  ): Promise<void> {
    this.metrics.fraudEvents.inc({ type });
    try {
      const [, user] = await this.prisma.$transaction([
        this.prisma.fraudEvent.create({
          data: { userId, type, score, details: details as object },
        }),
        this.prisma.user.update({
          where: { id: userId },
          data: { fraudScore: { increment: score } },
          select: { id: true, role: true, isActive: true, fraudScore: true },
        }),
      ]);

      const before = user.fraudScore - score;

      if (
        user.fraudScore >= FraudService.WARN_THRESHOLD &&
        before < FraudService.WARN_THRESHOLD
      ) {
        await this.prisma.notification.create({
          data: {
            userId,
            type: 'system',
            title: 'Account Warning',
            body: 'Unusual activity has been detected on your account. Continued violations may lead to suspension.',
          },
        });
      }

      if (
        user.fraudScore >= FraudService.SUSPEND_THRESHOLD &&
        user.isActive &&
        user.role === 'user'
      ) {
        await this.prisma.user.update({
          where: { id: userId },
          data: { isActive: false },
        });
        await this.prisma.authSession.deleteMany({ where: { userId } });
        await this.audit.log('system', 'fraud.auto_suspended', 'user', userId, {
          fraudScore: user.fraudScore,
          triggeringEvent: type,
        });
        this.logger.warn(
          `User ${userId} auto-suspended (fraud score ${user.fraudScore})`,
        );
        this.alerts.record('fraud_suspend');
      }
    } catch (error) {
      this.logger.error(
        `Fraud event write failed for ${userId}: ${(error as Error).message}`,
      );
    }
  }
}
