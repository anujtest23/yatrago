import { Injectable, OnModuleInit, OnModuleDestroy } from '@nestjs/common';
import Redis from 'ioredis';
import { appConfig } from '../../config/app.config';

@Injectable()
export class RedisService implements OnModuleInit, OnModuleDestroy {
  private client: Redis;

  onModuleInit() {
    this.client = new Redis({
      host: appConfig.redisHost,
      port: appConfig.redisPort,
    });
    this.client.on('connect', () => console.log('Redis connected'));
    this.client.on('error', (err) => console.error('Redis error', err));
  }

  async onModuleDestroy() {
    await this.client.quit();
  }

  // Store OTP — expires in 5 minutes
  async setOtp(phone: string, otp: string): Promise<void> {
    await this.client.set(`otp:${phone}`, otp, 'EX', 300);
  }

  // Get OTP
  async getOtp(phone: string): Promise<string | null> {
    return this.client.get(`otp:${phone}`);
  }

  // Delete OTP after verified
  async deleteOtp(phone: string): Promise<void> {
    await this.client.del(`otp:${phone}`);
  }

  // Count an OTP send for this phone; returns the count within the
  // rolling 10-minute window. Caller rejects when count exceeds limit.
  async incrementOtpSendCount(phone: string): Promise<number> {
    const key = `otp_sends:${phone}`;
    const count = await this.client.incr(key);
    if (count === 1) {
      await this.client.expire(key, 600);
    }
    return count;
  }

  // Count a failed OTP verification; window 10 minutes.
  async incrementOtpFailCount(phone: string): Promise<number> {
    const key = `otp_fails:${phone}`;
    const count = await this.client.incr(key);
    if (count === 1) {
      await this.client.expire(key, 600);
    }
    return count;
  }

  async getOtpFailCount(phone: string): Promise<number> {
    const val = await this.client.get(`otp_fails:${phone}`);
    return val ? parseInt(val, 10) : 0;
  }

  async clearOtpFailCount(phone: string): Promise<void> {
    await this.client.del(`otp_fails:${phone}`);
  }

  // Block a refresh token on logout
  async blacklistToken(token: string, ttlSeconds: number): Promise<void> {
    await this.client.set(`blacklist:${token}`, '1', 'EX', ttlSeconds);
  }

  // Check if token is blacklisted
  async isBlacklisted(token: string): Promise<boolean> {
    const val = await this.client.get(`blacklist:${token}`);
    return val === '1';
  }
}