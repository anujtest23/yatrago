import {
  Injectable,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { PrismaService } from '../../database/prisma.service';
import { UpdateUserDto } from './dto/update-user.dto';
import { RegisterDeviceTokenDto } from './dto/register-device-token.dto';
import { UpdateNotificationSettingsDto } from './dto/update-notification-settings.dto';
import { mergeNotificationSettings } from '../notifications/notification-preferences';

@Injectable()
export class UsersService {
  constructor(private prisma: PrismaService) {}

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

  // ── DELETE /users/me ────────────────────────────────────────
  async deleteMe(userId: string) {
    // Cannot delete with active passenger bookings
    const activeBookings = await this.prisma.booking.count({
      where: {
        passengerId: userId,
        status: { in: ['pending', 'confirmed'] as any },
      },
    });
    if (activeBookings > 0) {
      throw new BadRequestException('Cancel your active bookings/rides first');
    }

    // Drivers cannot delete with published or in-progress rides
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
        throw new BadRequestException(
          'Cancel your active bookings/rides first',
        );
      }
    }

    // Soft delete — deactivate now; the account-deletion cron anonymizes
    // the personal data after the 30-day grace period.
    await this.prisma.user.update({
      where: { id: userId },
      data: {
        deletionRequestedAt: new Date(),
        isActive: false,
      },
    });

    // Force logout everywhere
    await this.prisma.authSession.deleteMany({ where: { userId } });

    return {
      message:
        'Account deletion requested. Your account is deactivated and your data will be permanently anonymized after a 30-day grace period. Log in again within 30 days to reactivate your account.',
    };
  }
}
