import { Injectable, Logger } from '@nestjs/common';
import axios from 'axios';
import { PrismaService } from '../../database/prisma.service';
import { AuditService } from './audit.service';
import { appConfig } from '../../config/app.config';

interface AlertRule {
  threshold: number;
  windowMs: number;
  description: string;
}

/**
 * In-process security alerting: sliding-window counters over security
 * events; crossing a threshold notifies every admin in-app, writes an audit
 * row, and (optionally) POSTs to SECURITY_ALERT_WEBHOOK — a Slack-compatible
 * `{ text }` JSON payload.
 *
 * Windows are per-instance. That is deliberate: this is a first-response
 * tripwire, not a metrics system — Prometheus (see MetricsService) is the
 * cross-instance source of truth for dashboards and Alertmanager rules.
 */
@Injectable()
export class SecurityAlertsService {
  private readonly logger = new Logger(SecurityAlertsService.name);

  private static readonly RULES: Record<string, AlertRule> = {
    otp_lockout: {
      threshold: 10,
      windowMs: 10 * 60_000,
      description: 'OTP brute-force suspected (lockout spike)',
    },
    refresh_reuse: {
      threshold: 3,
      windowMs: 10 * 60_000,
      description: 'Refresh-token theft spike (reuse detections)',
    },
    fraud_suspend: {
      threshold: 5,
      windowMs: 60 * 60_000,
      description: 'Fraud surge (multiple auto-suspensions)',
    },
  };

  private events = new Map<string, number[]>();
  private lastAlertAt = new Map<string, number>();

  constructor(
    private prisma: PrismaService,
    private audit: AuditService,
  ) {}

  /** Record a security event; fires an alert when the rule threshold trips. */
  record(type: keyof typeof SecurityAlertsService.RULES): void {
    const rule = SecurityAlertsService.RULES[type];
    if (!rule) return;

    const now = Date.now();
    const bucket = (this.events.get(type) ?? []).filter(
      (t) => now - t < rule.windowMs,
    );
    bucket.push(now);
    this.events.set(type, bucket);

    if (bucket.length < rule.threshold) return;
    // One alert per window — don't spam ops during a sustained attack.
    if (now - (this.lastAlertAt.get(type) ?? 0) < rule.windowMs) return;
    this.lastAlertAt.set(type, now);

    void this.dispatch(type, rule, bucket.length);
  }

  private async dispatch(
    type: string,
    rule: AlertRule,
    count: number,
  ): Promise<void> {
    const text = `[SECURITY ALERT] ${rule.description}: ${count} events in ${Math.round(rule.windowMs / 60_000)} min (${appConfig.nodeEnv})`;
    this.logger.error(text);

    try {
      await this.audit.log('system', 'security.alert', 'alert', type, {
        count,
        windowMinutes: Math.round(rule.windowMs / 60_000),
      });

      const admins = await this.prisma.user.findMany({
        where: { role: { in: ['admin', 'super_admin'] }, isActive: true },
        select: { id: true },
      });
      if (admins.length > 0) {
        await this.prisma.notification.createMany({
          data: admins.map((a) => ({
            userId: a.id,
            type: 'system' as const,
            title: 'Security Alert',
            body: text,
          })),
        });
      }

      if (appConfig.securityAlertWebhook) {
        await axios.post(
          appConfig.securityAlertWebhook,
          { text },
          { timeout: 10_000 },
        );
      }
    } catch (error) {
      this.logger.error(
        `Security alert dispatch failed: ${(error as Error).message}`,
      );
    }
  }
}
