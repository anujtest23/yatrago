import {
  Injectable,
  BadRequestException,
  UnauthorizedException,
  NotFoundException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { PrismaService } from '../../database/prisma.service';
import { RedisService } from './redis.service';
import { SendOtpDto } from './dto/send-otp.dto';
import { VerifyOtpDto } from './dto/verify-otp.dto';
import { appConfig } from '../../config/app.config';
import axios from 'axios';

@Injectable()
export class AuthService {
  constructor(
    private prisma: PrismaService,
    private redis: RedisService,
    private jwt: JwtService,
  ) {}

  // ── Generate a 6-digit OTP ──────────────────────────────────
  private generateOtp(): string {
    return Math.floor(100000 + Math.random() * 900000).toString();
  }

  // ── Send OTP via Sparrow SMS ────────────────────────────────
  private async sendSms(phone: string, otp: string): Promise<void> {
    const message = `Your YatraGo OTP is ${otp}. Valid for 5 minutes. Do not share this with anyone.`;

    // In development, just log the OTP instead of sending real SMS
    if (appConfig.nodeEnv === 'development' || !appConfig.sparrowToken) {
      console.log(`[DEV] OTP for ${phone}: ${otp}`);
      return;
    }

    try {
      await axios.get('http://api.sparrowsms.com/v2/sms/', {
        params: {
          token: appConfig.sparrowToken,
          from: appConfig.sparrowFrom,
          to: phone,
          text: message,
        },
      });
    } catch (error) {
      console.error('SMS send failed:', error.message);
      // Don't throw — OTP is still stored, user can retry
    }
  }

  // ── Generate access + refresh tokens ───────────────────────
  private async generateTokens(userId: string, phone: string) {
    const payload = { sub: userId, phone };

    const accessToken = this.jwt.sign(payload, {
      expiresIn: appConfig.jwtExpiresIn,
    });

    const refreshToken = this.jwt.sign(payload, {
      expiresIn: appConfig.jwtRefreshExpiresIn,
    });

    // Save refresh token to database
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + 30);

    await this.prisma.authSession.create({
      data: {
        userId,
        refreshToken,
        expiresAt,
      },
    });

    return { accessToken, refreshToken };
  }

  // ── POST /auth/send-otp ─────────────────────────────────────
  async sendOtp(dto: SendOtpDto) {
    const otp = this.generateOtp();
    await this.redis.setOtp(dto.phoneNumber, otp);
    await this.sendSms(dto.phoneNumber, otp);

    return {
      message: 'OTP sent successfully',
      // Only return OTP in development so you can test without real SMS
      ...(appConfig.nodeEnv === 'development' && { otp }),
    };
  }

  // ── POST /auth/verify-otp ───────────────────────────────────
  async verifyOtp(dto: VerifyOtpDto) {
    const storedOtp = await this.redis.getOtp(dto.phoneNumber);

    if (!storedOtp) {
      throw new BadRequestException(
        'OTP expired or not found. Please request a new one.',
      );
    }

    if (storedOtp !== dto.otp) {
      throw new BadRequestException('Invalid OTP. Please try again.');
    }

    // OTP is correct — delete it so it can't be reused
    await this.redis.deleteOtp(dto.phoneNumber);

    // Find or create user
    let user = await this.prisma.user.findUnique({
      where: { phoneNumber: dto.phoneNumber },
    });

    const isNewUser = !user;

    if (!user) {
      user = await this.prisma.user.create({
        data: { phoneNumber: dto.phoneNumber },
      });
    }

    const tokens = await this.generateTokens(user.id, user.phoneNumber);

    return {
      message: isNewUser ? 'Account created successfully' : 'Login successful',
      isNewUser,
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      user: {
        id: user.id,
        phoneNumber: user.phoneNumber,
        fullName: user.fullName,
        profilePhotoUrl: user.profilePhotoUrl,
        activeMode: user.activeMode,
        isVerified: user.isVerified,
      },
    };
  }

  // ── POST /auth/logout ───────────────────────────────────────
  async logout(refreshToken: string) {
    // Delete session from database
    await this.prisma.authSession.deleteMany({
      where: { refreshToken },
    });

    // Blacklist the token in Redis for its remaining TTL
    await this.redis.blacklistToken(refreshToken, 60 * 60 * 24 * 30);

    return { message: 'Logged out successfully' };
  }

  // ── GET /auth/me ────────────────────────────────────────────
  async getMe(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        phoneNumber: true,
        fullName: true,
        profilePhotoUrl: true,
        gender: true,
        dateOfBirth: true,
        activeMode: true,
        isVerified: true,
        createdAt: true,
        driverProfile: {
          select: {
            verificationStatus: true,
            averageRating: true,
            totalTrips: true,
          },
        },
      },
    });

    if (!user) {
      throw new NotFoundException('User not found');
    }

    return user;
  }
}