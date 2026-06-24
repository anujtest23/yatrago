import {
  Injectable,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { PrismaService } from '../../database/prisma.service';
import { UpdateUserDto } from './dto/update-user.dto';

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

    // For MVP we store the file locally and serve it statically
    // Later this will upload to Cloudflare R2
    const filename = `${userId}-${Date.now()}-${file.originalname}`;
    const photoUrl = `/uploads/${filename}`;

    const user = await this.prisma.user.update({
      where: { id: userId },
      data: { profilePhotoUrl: photoUrl },
      select: { id: true, profilePhotoUrl: true },
    });

    return { message: 'Profile photo updated', profilePhotoUrl: user.profilePhotoUrl };
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

  // ── DELETE /users/me ────────────────────────────────────────
  async deleteMe(userId: string) {
    // Soft delete — set isActive to false, don't actually delete
    await this.prisma.user.update({
      where: { id: userId },
      data: { isActive: false },
    });

    return { message: 'Account deactivated successfully' };
  }
}