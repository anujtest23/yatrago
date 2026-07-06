import { Injectable, Logger } from '@nestjs/common';
import { createHash } from 'crypto';
import { PrismaService } from '../../database/prisma.service';
import { GeoIpService, GeoLookup } from './geoip.service';
import { TorExitService } from './tor-exit.service';
import { FraudService } from './fraud.service';
import { SmsService } from './sms.service';
import { AuditService } from './audit.service';

/** What auth should persist on the new session row. */
export interface LoginAssessment {
  geo: GeoLookup;
  deviceIdHash: string | null;
}

/** Anything faster than a commercial flight between logins is not travel. */
const IMPOSSIBLE_SPEED_KMH = 900;
/** Devices seen on this many OTHER accounts within 30 days = farming. */
const DEVICE_ACCOUNT_LIMIT = 3;

function haversineKm(
  lat1: number,
  lng1: number,
  lat2: number,
  lng2: number,
): number {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLng = ((lng2 - lng1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(a));
}

/**
 * Login-time anomaly assessment (OWASP ASVS 2.2 / API Top 10 anti-automation):
 *
 *  - country change vs. the previous session          → fraud +20 + SMS
 *  - impossible travel (GeoIP distance over elapsed)  → fraud +30 + SMS
 *  - login from a Tor exit node                       → fraud +15
 *  - same device cycling through many accounts        → fraud +25 (farming)
 *
 * Everything here is additive signal for FraudService — the cumulative-score
 * thresholds decide warnings/suspension. Assessment failures never block a
 * login (enrichment, not enforcement).
 */
@Injectable()
export class LoginAnomalyService {
  private readonly logger = new Logger(LoginAnomalyService.name);

  constructor(
    private prisma: PrismaService,
    private geoip: GeoIpService,
    private torExits: TorExitService,
    private fraud: FraudService,
    private sms: SmsService,
    private audit: AuditService,
  ) {}

  /** GeoIP lookup passthrough (used by refresh to keep session geo fresh). */
  lookupGeo(ip: string): GeoLookup {
    return this.geoip.lookup(ip);
  }

  /** Normalize the client device identifier: hash server-side, cap length. */
  hashDeviceId(raw?: string): string | null {
    if (!raw) return null;
    const cleaned = raw.trim().slice(0, 256);
    if (!cleaned) return null;
    return createHash('sha256').update(cleaned).digest('hex');
  }

  /** Scores for client-reported runtime flags (X-Device-Integrity). */
  private static readonly INTEGRITY_SCORES: Record<string, number> = {
    rooted: 15,
    frida: 25,
    emulator: 10,
    debug: 0, // expected during development; recorded but unscored
  };

  async assessLogin(
    user: { id: string; phoneNumber: string },
    ctx: { ip: string; deviceId?: string; integrityFlags?: string[] },
    isNewUser: boolean,
  ): Promise<LoginAssessment> {
    const geo = this.geoip.lookup(ctx.ip);
    const deviceIdHash = this.hashDeviceId(ctx.deviceId);

    try {
      if (this.torExits.isTorExit(ctx.ip)) {
        await this.fraud.record(user.id, 'tor_exit_login', 15, { ip: ctx.ip });
      }

      const flagged = (ctx.integrityFlags ?? []).filter(
        (f) => (LoginAnomalyService.INTEGRITY_SCORES[f] ?? 0) > 0,
      );
      if (flagged.length > 0) {
        const score = flagged.reduce(
          (sum, f) => sum + LoginAnomalyService.INTEGRITY_SCORES[f],
          0,
        );
        await this.fraud.record(user.id, 'device_integrity', score, {
          flags: flagged,
        });
      }

      if (deviceIdHash && isNewUser) {
        await this.checkAccountFarming(user.id, deviceIdHash);
      }

      if (!isNewUser && geo.country) {
        await this.checkGeoAnomalies(user, geo);
      }
    } catch (error) {
      this.logger.warn(
        `Login anomaly assessment failed for ${user.id}: ${(error as Error).message}`,
      );
    }

    return { geo, deviceIdHash };
  }

  /** New account on a device already used by several other accounts. */
  private async checkAccountFarming(
    userId: string,
    deviceIdHash: string,
  ): Promise<void> {
    const since = new Date(Date.now() - 30 * 24 * 3600_000);
    const rows = await this.prisma.authSession.findMany({
      where: {
        deviceId: deviceIdHash,
        createdAt: { gte: since },
        userId: { not: userId },
      },
      select: { userId: true },
      distinct: ['userId'],
    });
    if (rows.length >= DEVICE_ACCOUNT_LIMIT) {
      await this.fraud.record(userId, 'device_multi_account', 25, {
        otherAccounts: rows.length,
      });
      await this.audit.log(
        'system',
        'security.account_farming_suspected',
        'user',
        userId,
        { otherAccounts: rows.length },
      );
    }
  }

  /** Country change + impossible travel vs. the most recent session. */
  private async checkGeoAnomalies(
    user: { id: string; phoneNumber: string },
    geo: GeoLookup,
  ): Promise<void> {
    const last = await this.prisma.authSession.findFirst({
      where: { userId: user.id, country: { not: null } },
      orderBy: { lastUsedAt: 'desc' },
      select: { country: true, geoLat: true, geoLng: true, lastUsedAt: true },
    });
    if (!last?.country) return;

    let notify = false;

    if (last.country !== geo.country) {
      await this.fraud.record(user.id, 'geo_country_change', 20, {
        from: last.country,
        to: geo.country,
      });
      notify = true;
    }

    if (
      last.geoLat !== null &&
      last.geoLng !== null &&
      geo.lat !== null &&
      geo.lng !== null
    ) {
      const km = haversineKm(last.geoLat, last.geoLng, geo.lat, geo.lng);
      const hours = Math.max(
        (Date.now() - last.lastUsedAt.getTime()) / 3600_000,
        1 / 60, // floor at one minute so a same-second replay can't divide by ~0
      );
      if (km > 100 && km / hours > IMPOSSIBLE_SPEED_KMH) {
        await this.fraud.record(user.id, 'geo_impossible_travel', 30, {
          km: Math.round(km),
          hours: Number(hours.toFixed(2)),
        });
        notify = true;
      }
    }

    if (notify) {
      // Account-takeover warning straight to the owner's phone.
      await this.sms.send(
        user.phoneNumber,
        'YatraGo: your account was just accessed from an unusual location. If this was not you, open the app and log out of all devices immediately.',
      );
    }
  }
}
