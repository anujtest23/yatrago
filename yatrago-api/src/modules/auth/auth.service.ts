import {
  Injectable,
  BadRequestException,
  UnauthorizedException,
  NotFoundException,
  ForbiddenException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { PrismaService } from '../../database/prisma.service';
import { RedisService } from './redis.service';
import { SendOtpDto } from './dto/send-otp.dto';
import { VerifyOtpDto } from './dto/verify-otp.dto';
import { appConfig } from '../../config/app.config';
import { SmsService } from '../platform/sms.service';

@Injectable()
export class AuthService {
  constructor(
    private prisma: PrismaService,
    private redis: RedisService,
    private jwt: JwtService,
    private sms: SmsService,
  ) {}

  // ── Generate a 6-digit OTP ──────────────────────────────────
  private generateOtp(): string {
    return Math.floor(100000 + Math.random() * 900000).toString();
  }

  // ── Send OTP via Sparrow SMS (delegates to shared SmsService) ──
  private async sendSms(phone: string, otp: string): Promise<void> {
    const message = `Your YatraGo OTP is ${otp}. Valid for 5 minutes. Do not share this with anyone.`;
    await this.sms.send(phone, message);
  }

  // ── Generate access + refresh tokens ───────────────────────
  private async generateTokens(userId: string, phone: string) {
    const payload = { sub: userId, phone };

    const accessToken = this.jwt.sign(payload, {
      secret: appConfig.jwtSecret,
      expiresIn: appConfig.jwtExpiresIn,
    });

    const refreshToken = this.jwt.sign(payload, {
      secret: appConfig.jwtSecret,
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
    // Rate limit: max 3 OTP sends per phone per 10 minutes
    const sendCount = await this.redis.incrementOtpSendCount(dto.phoneNumber);
    if (sendCount > 3) {
      throw new BadRequestException(
        'Too many OTP requests. Please try again in 10 minutes.',
      );
    }

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
    // Lock out after 5 failed attempts within 10 minutes
    const failCount = await this.redis.getOtpFailCount(dto.phoneNumber);
    if (failCount >= 5) {
      throw new BadRequestException(
        'Too many failed attempts. Please try again in 10 minutes.',
      );
    }

    const storedOtp = await this.redis.getOtp(dto.phoneNumber);

    if (!storedOtp) {
      throw new BadRequestException(
        'OTP expired or not found. Please request a new one.',
      );
    }

    if (storedOtp !== dto.otp) {
      await this.redis.incrementOtpFailCount(dto.phoneNumber);
      throw new BadRequestException('Invalid OTP. Please try again.');
    }

    // OTP is correct — delete it so it can't be reused
    await this.redis.deleteOtp(dto.phoneNumber);
    await this.redis.clearOtpFailCount(dto.phoneNumber);

    // Find or create user
    let user = await this.prisma.user.findUnique({
      where: { phoneNumber: dto.phoneNumber },
    });

    const isNewUser = !user;

    if (!user) {
      user = await this.prisma.user.create({
        data: { phoneNumber: dto.phoneNumber },
      });
    } else if (!user.isActive) {
      if (user.deletionRequestedAt) {
        // Grace-period recovery: user requested deletion but is not yet
        // anonymized (anonymized accounts get a 'deleted-' phone number and
        // can never match an OTP login). Logging in reactivates the account.
        user = await this.prisma.user.update({
          where: { id: user.id },
          data: { deletionRequestedAt: null, isActive: true },
        });
      } else {
        // isActive false without a deletion request = blocked by admin
        throw new ForbiddenException('Account suspended');
      }
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
        role: user.role,
        isVerified: user.isVerified,
      },
    };
  }

  // ── POST /auth/refresh ──────────────────────────────────────
  async refresh(refreshToken: string) {
    // Reject blacklisted (logged-out) tokens
    if (await this.redis.isBlacklisted(refreshToken)) {
      throw new UnauthorizedException('Refresh token has been revoked');
    }

    // Verify signature and expiry
    let payload: { sub: string; phone: string };
    try {
      payload = this.jwt.verify(refreshToken, {
        secret: appConfig.jwtSecret,
      });
    } catch {
      throw new UnauthorizedException('Invalid or expired refresh token');
    }

    // Token must correspond to a live session
    const session = await this.prisma.authSession.findUnique({
      where: { refreshToken },
    });
    if (!session || session.expiresAt < new Date()) {
      throw new UnauthorizedException('Session expired. Please log in again.');
    }

    const user = await this.prisma.user.findUnique({
      where: { id: payload.sub },
    });
    if (!user || !user.isActive) {
      throw new UnauthorizedException('Account is not active');
    }

    // Rotate: invalidate the old session, issue a fresh pair
    await this.prisma.authSession.delete({ where: { id: session.id } });
    await this.redis.blacklistToken(refreshToken, 60 * 60 * 24 * 30);

    const tokens = await this.generateTokens(user.id, user.phoneNumber);

    return {
      message: 'Tokens refreshed',
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
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
        role: true,
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