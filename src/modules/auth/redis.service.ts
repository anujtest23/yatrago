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