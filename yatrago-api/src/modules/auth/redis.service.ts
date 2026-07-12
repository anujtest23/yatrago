import {
  Injectable,
  Logger,
  OnModuleDestroy,
  OnModuleInit,
} from '@nestjs/common';
import Redis from 'ioredis';
import { createHmac, timingSafeEqual } from 'crypto';
import { appConfig } from '../../config/app.config';

/**
 * Redis-backed auth state.
 *
 * Security notes:
 *  - OTPs are stored as HMAC-SHA256(pepper, phone:otp), never in plaintext,
 *    so a Redis dump or debug session can't reveal live codes.
 *  - Comparison is timing-safe.
 *  - Rotated/revoked refresh tokens are blacklisted BY HASH and mapped to
 *    their session family, enabling token-theft (reuse) detection.
 */
@Injectable()
export class RedisService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(RedisService.name);
  private client!: Redis;

  onModuleInit() {
    this.client = new Redis({
      host: appConfig.redisHost,
      port: appConfig.redisPort,
      password: appConfig.redisPassword,
      maxRetriesPerRequest: 3,
    });
    this.client.on('connect', () => this.logger.log('Redis connected'));
    this.client.on('error', (err) =>
      this.logger.error(`Redis error: ${err.message}`),
    );
  }

  async onModuleDestroy() {
    await this.client.quit();
  }

  // ── OTP storage (hashed at rest) ──────────────────────────────

  private hashOtp(phone: string, otp: string): string {
    return createHmac('sha256', appConfig.otpPepper)
      .update(`${phone}:${otp}`)
      .digest('hex');
  }

  /** Store OTP hash — expires in 5 minutes. */
  async setOtp(phone: string, otp: string): Promise<void> {
    await this.client.set(`otp:${phone}`, this.hashOtp(phone, otp), 'EX', 300);
  }

  /** True if an unexpired OTP exists for this phone. */
  async hasOtp(phone: string): Promise<boolean> {
    return (await this.client.exists(`otp:${phone}`)) === 1;
  }

  /** Timing-safe verification against the stored hash. */
  async verifyOtp(phone: string, otp: string): Promise<boolean> {
    const stored = await this.client.get(`otp:${phone}`);
    if (!stored) return false;
    const candidate = this.hashOtp(phone, otp);
    const a = Buffer.from(stored, 'hex');
    const b = Buffer.from(candidate, 'hex');
    return a.length === b.length && timingSafeEqual(a, b);
  }

  /** Delete OTP once verified (single use). */
  async deleteOtp(phone: string): Promise<void> {
    await this.client.del(`otp:${phone}`);
  }

  // ── Action OTPs (sensitive in-session operations e.g. account deletion) ──
  // Namespaced by a caller-supplied scope so they never collide with the
  // login OTP keyed on the raw phone number.

  /** Store an action OTP hash for `scope` — expires in 5 minutes. */
  async setActionOtp(scope: string, otp: string): Promise<void> {
    await this.client.set(
      `action_otp:${scope}`,
      this.hashOtp(scope, otp),
      'EX',
      300,
    );
  }

  /** Timing-safe verification of an action OTP; single-use on success. */
  async verifyActionOtp(scope: string, otp: string): Promise<boolean> {
    const stored = await this.client.get(`action_otp:${scope}`);
    if (!stored) return false;
    const candidate = this.hashOtp(scope, otp);
    const a = Buffer.from(stored, 'hex');
    const b = Buffer.from(candidate, 'hex');
    const ok = a.length === b.length && timingSafeEqual(a, b);
    if (ok) await this.client.del(`action_otp:${scope}`);
    return ok;
  }

  // ── Abuse counters ────────────────────────────────────────────

  private async incrementWindow(
    key: string,
    windowSeconds: number,
  ): Promise<number> {
    const count = await this.client.incr(key);
    if (count === 1) {
      await this.client.expire(key, windowSeconds);
    }
    return count;
  }

  /** OTP sends per phone; rolling 10-minute window. */
  async incrementOtpSendCount(phone: string): Promise<number> {
    return this.incrementWindow(`otp_sends:${phone}`, 600);
  }

  /** OTP sends per source IP; rolling 1-hour window (SIM-rotation abuse). */
  async incrementOtpIpCount(ip: string): Promise<number> {
    return this.incrementWindow(`otp_ip:${ip}`, 3600);
  }

  /** Failed OTP verifications per phone; rolling 10-minute window. */
  async incrementOtpFailCount(phone: string): Promise<number> {
    return this.incrementWindow(`otp_fails:${phone}`, 600);
  }

  async getOtpFailCount(phone: string): Promise<number> {
    const val = await this.client.get(`otp_fails:${phone}`);
    return val ? parseInt(val, 10) : 0;
  }

  async clearOtpFailCount(phone: string): Promise<void> {
    await this.client.del(`otp_fails:${phone}`);
  }

  /** Failed TOTP codes per user; rolling 10-minute window. */
  async incrementTotpFailCount(userId: string): Promise<number> {
    return this.incrementWindow(`totp_fails:${userId}`, 600);
  }

  async getTotpFailCount(userId: string): Promise<number> {
    const val = await this.client.get(`totp_fails:${userId}`);
    return val ? parseInt(val, 10) : 0;
  }

  async clearTotpFailCount(userId: string): Promise<void> {
    await this.client.del(`totp_fails:${userId}`);
  }

  // ── Refresh-token revocation (by hash) ────────────────────────

  /**
   * Blacklist a rotated/revoked refresh-token hash and remember which
   * session family it belonged to. A later lookup hit means the token
   * was REUSED after rotation — i.e. stolen — and the whole family
   * must be revoked.
   */
  async blacklistRefreshHash(
    tokenHash: string,
    familyId: string,
    ttlSeconds: number,
  ): Promise<void> {
    await this.client.set(`bl_rt:${tokenHash}`, familyId, 'EX', ttlSeconds);
  }

  /** Returns the family id if this hash was already rotated/revoked. */
  async getBlacklistedFamily(tokenHash: string): Promise<string | null> {
    return this.client.get(`bl_rt:${tokenHash}`);
  }
}
