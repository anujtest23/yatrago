import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../database/prisma.service';

// Business policy defaults. Admin can override any of these via the
// app_config table (PATCH /admin/config); DB values win over defaults.
export const CONFIG_DEFAULTS = {
  commission_percent: 10,
  commission_mode: 0, // 0 = percent of ride fares, 1 = fixed NPR per ride
  commission_fixed: 50, // flat NPR per completed ride when commission_mode = 1
  min_wallet_balance: 500, // driver must hold this to post rides / accept bookings
  price_cap_per_km: 55, // NPR per km (Nepal draft rule)
  full_refund_hours: 24, // cancel earlier than this → 100% refund
  half_refund_hours: 6, // cancel earlier than this → 50% refund
  min_payout_npr: 500,
  booking_expiry_minutes: 15, // pending bookings older than this expire
  min_departure_minutes: 10,
  max_departure_days: 180,
} as const;

export type ConfigKey = keyof typeof CONFIG_DEFAULTS;

@Injectable()
export class AppConfigService {
  private cache = new Map<string, { value: number; expiresAt: number }>();
  private static CACHE_TTL_MS = 60_000;

  constructor(private prisma: PrismaService) {}

  async get(key: ConfigKey): Promise<number> {
    const cached = this.cache.get(key);
    if (cached && cached.expiresAt > Date.now()) return cached.value;

    const row = await this.prisma.appConfig.findUnique({ where: { key } });
    const value =
      row && typeof row.value === 'number'
        ? row.value
        : CONFIG_DEFAULTS[key];

    this.cache.set(key, {
      value,
      expiresAt: Date.now() + AppConfigService.CACHE_TTL_MS,
    });
    return value;
  }

  async getAll(): Promise<Record<ConfigKey, number>> {
    const rows = await this.prisma.appConfig.findMany();
    const result = { ...CONFIG_DEFAULTS } as Record<ConfigKey, number>;
    for (const row of rows) {
      if (row.key in CONFIG_DEFAULTS && typeof row.value === 'number') {
        result[row.key as ConfigKey] = row.value;
      }
    }
    return result;
  }

  async set(key: ConfigKey, value: number): Promise<void> {
    await this.prisma.appConfig.upsert({
      where: { key },
      create: { key, value },
      update: { value },
    });
    this.cache.delete(key);
  }
}
