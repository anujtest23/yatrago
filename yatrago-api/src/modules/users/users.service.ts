import {
  Injectable,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { randomInt } from 'crypto';
import { PrismaService } from '../../database/prisma.service';
import { RedisService } from '../auth/redis.service';
import { SmsService } from '../platform/sms.service';
import { AuditService } from '../platform/audit.service';
import { appConfig } from '../../config/app.config';
import { UpdateUserDto } from './dto/update-user.dto';
import { RegisterDeviceTokenDto } from './dto/register-device-token.dto';
import { UpdateNotificationSettingsDto } from './dto/update-notification-settings.dto';
import { mergeNotificationSettings } from '../notifications/notification-preferences';
import {
  mergeNotificationPreferences,
  mergePrivacySettings,
} from './preferences';
import { UpdateNotificationPreferencesDto } from './dto/update-notification-preferences.dto';
import { UpdatePrivacySettingsDto } from './dto/update-privacy-settings.dto';

@Injectable()
export class UsersService {
  constructor(
    private prisma: PrismaService,
    private redis: RedisService,
    private sms: SmsService,
    private audit: AuditService,
  ) {}

  // ── GET /users/me ───────────────────────────────────────────
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
        language: true,
        activeMode: true,
        isVerified: true,
        createdAt: true,
        updatedAt: true,
        driverProfile: {
          select: {
            id: true,
            verificationStatus: true,
            averageRating: true,
            totalTrips: true,
          },
        },
      },
    });

    if (!user) throw new NotFoundException('User not found');
    return user;
  }

  // ── PATCH /users/me ─────────────────────────────────────────
  async updateMe(userId: string, dto: UpdateUserDto) {
    const user = await this.prisma.user.update({
      where: { id: userId },
      data: {
        ...(dto.fullName && { fullName: dto.fullName }),
        ...(dto.gender && { gender: dto.gender as any }),
        ...(dto.dateOfBirth && { dateOfBirth: new Date(dto.dateOfBirth) }),
        ...(dto.language && { language: dto.language }),
      },
      select: {
        id: true,
        phoneNumber: true,
        fullName: true,
        profilePhotoUrl: true,
        gender: true,
        dateOfBirth: true,
        language: true,
        activeMode: true,
        isVerified: true,
        updatedAt: true,
      },
    });

    return { message: 'Profile updated successfully', user };
  }

  // ── POST /users/profile-photo ───────────────────────────────
  async updateProfilePhoto(userId: string, file: Express.Multer.File) {
    if (!file) throw new BadRequestException('No file provided');

    // file.filename is the server-generated UUID name multer actually wrote
    // to disk — never derive the URL from the client-supplied originalname.
    const photoUrl = `/uploads/${file.filename}`;

    const user = await this.prisma.user.update({
      where: { id: userId },
      data: { profilePhotoUrl: photoUrl },
      select: { id: true, profilePhotoUrl: true },
    });

    return {
      message: 'Profile photo updated',
      profilePhotoUrl: user.profilePhotoUrl,
    };
  }

  // ── PATCH /users/me/mode ────────────────────────────────────
  async switchMode(userId: string, mode: 'passenger' | 'driver') {
    // If switching to driver, check verification status first
    if (mode === 'driver') {
      const driver = await this.prisma.driverProfile.findUnique({
        where: { userId },
      });

      return {
        canSwitch: driver?.verificationStatus === 'approved',
        verificationStatus: driver?.verificationStatus ?? 'not_submitted',
        message:
          driver?.verificationStatus === 'approved'
            ? 'Switched to driver mode'
            : 'Driver verification required',
      };
    }

    const user = await this.prisma.user.update({
      where: { id: userId },
      data: { activeMode: mode },
      select: { id: true, activeMode: true },
    });

    return { message: `Switched to ${mode} mode`, activeMode: user.activeMode };
  }

  // ── POST /users/me/device-token ─────────────────────────────
  async registerDeviceToken(userId: string, dto: RegisterDeviceTokenDto) {
    // Upsert by token — if another user previously registered this
    // device, reassign it to the current user.
    const token = await this.prisma.deviceToken.upsert({
      where: { fcmToken: dto.fcmToken },
      create: {
        userId,
        fcmToken: dto.fcmToken,
        platform: dto.platform as any,
      },
      update: {
        userId,
        platform: dto.platform as any,
      },
    });

    return { message: 'Device token registered', deviceTokenId: token.id };
  }

  // ── GET /users/me/notification-settings ─────────────────────
  async getNotificationSettings(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { notificationSettings: true },
    });
    if (!user) throw new NotFoundException('User not found');

    return mergeNotificationSettings(user.notificationSettings);
  }

  // ── PATCH /users/me/notification-settings ────────────────────
  async updateNotificationSettings(
    userId: string,
    dto: UpdateNotificationSettingsDto,
  ) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { notificationSettings: true },
    });
    if (!user) throw new NotFoundException('User not found');

    // Merge the partial update over stored settings (over defaults)
    const merged = {
      ...mergeNotificationSettings(user.notificationSettings),
      ...(dto.bookings !== undefined && { bookings: dto.bookings }),
      ...(dto.trips !== undefined && { trips: dto.trips }),
      ...(dto.payments !== undefined && { payments: dto.payments }),
      ...(dto.promotions !== undefined && { promotions: dto.promotions }),
      ...(dto.safety !== undefined && { safety: dto.safety }),
    };

    await this.prisma.user.update({
      where: { id: userId },
      data: { notificationSettings: merged },
    });

    return {
      message: 'Notification settings updated',
      settings: merged,
    };
  }

  // ── Notification preferences (channel × category matrix) ─────
  async getNotificationPreferences(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { notificationPreferences: true },
    });
    if (!user) throw new NotFoundException('User not found');
    return mergeNotificationPreferences(user.notificationPreferences);
  }

  async updateNotificationPreferences(
    userId: string,
    dto: UpdateNotificationPreferencesDto,
  ) {
    const current = await this.getNotificationPreferences(userId);
    // Deep-merge only supplied channels over the current matrix.
    const merged = { ...current };
    for (const cat of Object.keys(dto) as (keyof typeof dto)[]) {
      const patch = dto[cat];
      if (patch) merged[cat] = { ...merged[cat], ...patch };
    }
    await this.prisma.user.update({
      where: { id: userId },
      data: { notificationPreferences: merged },
    });
    return { message: 'Notification preferences updated', preferences: merged };
  }

  // ── Privacy settings ─────────────────────────────────────────
  async getPrivacySettings(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { privacySettings: true },
    });
    if (!user) throw new NotFoundException('User not found');
    return mergePrivacySettings(user.privacySettings);
  }

  async updatePrivacySettings(userId: string, dto: UpdatePrivacySettingsDto) {
    const current = await this.getPrivacySettings(userId);
    const merged = { ...current };
    for (const key of Object.keys(dto) as (keyof UpdatePrivacySettingsDto)[]) {
      if (dto[key] !== undefined) (merged as any)[key] = dto[key];
    }
    await this.prisma.user.update({
      where: { id: userId },
      data: { privacySettings: merged },
    });
    return { message: 'Privacy settings updated', settings: merged };
  }

  // ── GET /users/me/export ────────────────────────────────────
  // GDPR-style data portability: everything we hold about the caller,
  // scoped strictly to their own id (no other user's data leaks in).
  async exportData(userId: string) {
    const [user, bookings, ratingsGiven, reports, sessions, wallet] =
      await Promise.all([
        this.prisma.user.findUnique({
          where: { id: userId },
          select: {
            id: true,
            phoneNumber: true,
            fullName: true,
            gender: true,
            dateOfBirth: true,
            language: true,
            role: true,
            createdAt: true,
            driverProfile: true,
          },
        }),
        this.prisma.booking.findMany({ where: { passengerId: userId } }),
        this.prisma.rating.findMany({ where: { raterId: userId } }),
        this.prisma.userReport.findMany({ where: { reporterId: userId } }),
        this.prisma.authSession.findMany({
          where: { userId },
          select: { deviceInfo: true, ipAddress: true, createdAt: true },
        }),
        this.prisma.wallet.findUnique({
          where: { userId },
          include: { transactions: true },
        }),
      ]);

    if (!user) throw new NotFoundException('User not found');

    return {
      exportedAt: new Date().toISOString(),
      profile: user,
      bookings,
      ratingsGiven,
      reports,
      sessions,
      wallet,
    };
  }

  // ── Account deletion (OTP-gated, 30-day grace period) ───────────
  //
  // Flow: request-otp → confirm (enter pending_deletion) → [grace period,
  // login+browse allowed, mutations blocked by PendingDeletionGuard] →
  // cron flips to `deleted` after 30 days. The user may cancel any time
  // during the grace period; logging in never cancels (business rule).

  // Deletion is refused while the account has commitments that would be
  // orphaned. Callers must clear these first.
  private async assertDeletable(userId: string) {
    const activeBookings = await this.prisma.booking.count({
      where: {
        passengerId: userId,
        status: { in: ['pending', 'confirmed'] as any },
      },
    });
    if (activeBookings > 0) {
      throw new BadRequestException('Cancel your active bookings/rides first');
    }

    const driver = await this.prisma.driverProfile.findUnique({
      where: { userId },
      select: { id: true },
    });
    if (driver) {
      const activeRides = await this.prisma.ride.count({
        where: {
          driverId: driver.id,
          status: { in: ['published', 'in_progress'] as any },
        },
      });
      if (activeRides > 0) {
        throw new BadRequestException('Cancel your active bookings/rides first');
      }
    }
  }

  // Step 1 — POST /users/me/deletion/request-otp
  async requestDeletionOtp(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { phoneNumber: true, accountStatus: true },
    });
    if (!user) throw new NotFoundException('User not found');
    if (user.accountStatus === 'pending_deletion') {
      throw new BadRequestException('Account is already pending deletion');
    }
    await this.assertDeletable(userId);

    // Per-phone send throttle, shared with the login OTP limiter.
    const sendCount = await this.redis.incrementOtpSendCount(user.phoneNumber);
    if (sendCount > 5) {
      throw new BadRequestException(
        'Too many OTP requests. Please try again in 10 minutes.',
      );
    }

    const otp = randomInt(0, 1_000_000).toString().padStart(6, '0');
    await this.redis.setActionOtp(`delete:${userId}`, otp);
    await this.sms.send(
      user.phoneNumber,
      `Your YatraGo account deletion code is ${otp}. Valid for 5 minutes. Do not share it. If you did not request this, ignore this message.`,
    );

    return {
      message: 'Verification code sent',
      ...(appConfig.nodeEnv === 'development' && { otp }),
    };
  }

  // Step 2 — POST /users/me/deletion/confirm
  async confirmDeletion(userId: string, otp: string) {
    if (!(await this.redis.verifyActionOtp(`delete:${userId}`, otp))) {
      throw new BadRequestException('Invalid or expired code');
    }
    await this.assertDeletable(userId);

    await this.prisma.user.update({
      where: { id: userId },
      data: {
        accountStatus: 'pending_deletion',
        deletionRequestedAt: new Date(),
        // isActive stays true: the user may still log in and browse during
        // the grace period. Mutations are blocked by PendingDeletionGuard.
      },
    });

    await this.audit.log(userId, 'account.deletion_requested', 'user', userId);

    return {
      message:
        'Account deletion scheduled. You have 30 days to cancel before your data is permanently removed. You can still browse, but bookings, rides, top-ups and payouts are disabled until you cancel.',
    };
  }

  // Step 3 — POST /users/me/deletion/cancel (no OTP; already authenticated)
  async cancelDeletion(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { accountStatus: true },
    });
    if (!user || user.accountStatus !== 'pending_deletion') {
      throw new BadRequestException('No pending deletion to cancel');
    }

    await this.prisma.user.update({
      where: { id: userId },
      data: { accountStatus: 'active', deletionRequestedAt: null },
    });

    await this.audit.log(userId, 'account.deletion_cancelled', 'user', userId);

    return { message: 'Account deletion cancelled. Your account is active.' };
  }
}
