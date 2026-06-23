import {
  Injectable,
  BadRequestException,
  NotFoundException,
  ConflictException,
} from '@nestjs/common';
import { PrismaService } from '../../database/prisma.service';
import { extname } from 'path';

@Injectable()
export class DriversService {
  constructor(private prisma: PrismaService) {}

  // ── POST /drivers/apply ─────────────────────────────────────
  async apply(userId: string) {
    // Check if driver profile already exists
    const existing = await this.prisma.driverProfile.findUnique({
      where: { userId },
    });

    if (existing) {
      // Already applied — just return current status
      return {
        message: 'Driver application already exists',
        verificationStatus: existing.verificationStatus,
        driverProfileId: existing.id,
      };
    }

    const driverProfile = await this.prisma.driverProfile.create({
      data: { userId },
      select: {
        id: true,
        verificationStatus: true,
        createdAt: true,
      },
    });

    // Update user activeMode to driver
    await this.prisma.user.update({
      where: { id: userId },
      data: { activeMode: 'driver' },
    });

    return {
      message: 'Driver application started. Please upload your documents.',
      verificationStatus: driverProfile.verificationStatus,
      driverProfileId: driverProfile.id,
    };
  }

  // ── POST /drivers/citizenship ───────────────────────────────
  async uploadCitizenship(
    userId: string,
    side: 'front' | 'back',
    file: Express.Multer.File,
  ) {
    if (!file) throw new BadRequestException('No file uploaded');

    const driver = await this.getDriverProfile(userId);
    const docType = side === 'front' ? 'citizenship_front' : 'citizenship_back';
    const fileUrl = `/uploads/${file.filename}`;

    await this.prisma.driverDocument.upsert({
      where: {
        driverId_docType: {
          driverId: driver.id,
          docType: docType as any,
        },
      },
      create: {
        driverId: driver.id,
        docType: docType as any,
        fileUrl,
        status: 'pending',
      },
      update: {
        fileUrl,
        status: 'pending',
        rejectionReason: null,
      },
    });

    // Check if both sides uploaded — update status
    await this.checkAndUpdateVerificationStatus(driver.id);

    return {
      message: `Citizenship ${side} uploaded successfully`,
      docType,
      fileUrl,
    };
  }

  // ── POST /drivers/license ───────────────────────────────────
  async uploadLicense(
    userId: string,
    side: 'front' | 'back',
    file: Express.Multer.File,
  ) {
    if (!file) throw new BadRequestException('No file uploaded');

    const driver = await this.getDriverProfile(userId);
    const docType = side === 'front' ? 'license_front' : 'license_back';
    const fileUrl = `/uploads/${file.filename}`;

    await this.prisma.driverDocument.upsert({
      where: {
        driverId_docType: {
          driverId: driver.id,
          docType: docType as any,
        },
      },
      create: {
        driverId: driver.id,
        docType: docType as any,
        fileUrl,
        status: 'pending',
      },
      update: {
        fileUrl,
        status: 'pending',
        rejectionReason: null,
      },
    });

    await this.checkAndUpdateVerificationStatus(driver.id);

    return {
      message: `License ${side} uploaded successfully`,
      docType,
      fileUrl,
    };
  }

  // ── POST /drivers/selfie ────────────────────────────────────
  async uploadSelfie(userId: string, file: Express.Multer.File) {
    if (!file) throw new BadRequestException('No file uploaded');

    const driver = await this.getDriverProfile(userId);
    const fileUrl = `/uploads/${file.filename}`;

    await this.prisma.driverDocument.upsert({
      where: {
        driverId_docType: {
          driverId: driver.id,
          docType: 'selfie',
        },
      },
      create: {
        driverId: driver.id,
        docType: 'selfie',
        fileUrl,
        status: 'pending',
      },
      update: {
        fileUrl,
        status: 'pending',
        rejectionReason: null,
      },
    });

    await this.checkAndUpdateVerificationStatus(driver.id);

    return {
      message: 'Selfie uploaded successfully',
      fileUrl,
    };
  }

  // ── GET /drivers/status ─────────────────────────────────────
  async getStatus(userId: string) {
    const driver = await this.prisma.driverProfile.findUnique({
      where: { userId },
      select: {
        id: true,
        verificationStatus: true,
        rejectionReason: true,
        createdAt: true,
        documents: {
          select: {
            docType: true,
            status: true,
            rejectionReason: true,
          },
        },
      },
    });

    if (!driver) {
      return {
        verificationStatus: 'not_submitted',
        message: 'No driver application found. Call POST /drivers/apply first.',
        documents: [],
      };
    }

    // Build a checklist of what is uploaded and what is missing
    const uploadedTypes = driver.documents.map((d) => d.docType);
    const requiredDocs = [
      'citizenship_front',
      'citizenship_back',
      'license_front',
      'license_back',
      'selfie',
    ];

    const checklist = requiredDocs.map((doc) => ({
      docType: doc,
      uploaded: uploadedTypes.includes(doc as any),
      status: driver.documents.find((d) => d.docType === doc)?.status ?? 'not_uploaded',
      rejectionReason: driver.documents.find((d) => d.docType === doc)?.rejectionReason ?? null,
    }));

    return {
      verificationStatus: driver.verificationStatus,
      rejectionReason: driver.rejectionReason,
      checklist,
    };
  }

  // ── Helper: get driver profile or throw ─────────────────────
  private async getDriverProfile(userId: string) {
    const driver = await this.prisma.driverProfile.findUnique({
      where: { userId },
    });

    if (!driver) {
      throw new NotFoundException(
        'Driver profile not found. Call POST /drivers/apply first.',
      );
    }

    return driver;
  }

  // ── Helper: auto-update status to under_review ──────────────
  private async checkAndUpdateVerificationStatus(driverId: string) {
    const docs = await this.prisma.driverDocument.findMany({
      where: { driverId },
    });

    const uploadedTypes = docs.map((d) => d.docType);
    const requiredDocs = [
      'citizenship_front',
      'citizenship_back',
      'license_front',
      'license_back',
      'selfie',
    ];

    const allUploaded = requiredDocs.every((doc) =>
      uploadedTypes.includes(doc as any),
    );

    if (allUploaded) {
      await this.prisma.driverProfile.update({
        where: { id: driverId },
        data: { verificationStatus: 'under_review' },
      });
    }
  }
  // ── GET /drivers/dashboard ───────────────────────────────────
  async getDashboard(userId: string) {
    const driver = await this.prisma.driverProfile.findUnique({
      where: { userId },
    });

    if (!driver) {
      return {
        verificationStatus: 'not_submitted',
        message: 'Complete driver verification to access dashboard',
      };
    }

    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);

    const [
      upcomingTrips,
      pendingBookings,
      todayEarnings,
      totalEarnings,
      recentActivity,
    ] = await Promise.all([
      // Upcoming published trips
      this.prisma.ride.findMany({
        where: {
          driverId: driver.id,
          status: 'published',
          departureAt: { gte: new Date() },
        },
        orderBy: { departureAt: 'asc' },
        take: 5,
        select: {
          id: true,
          originName: true,
          destName: true,
          departureAt: true,
          availableSeats: true,
          totalSeats: true,
          pricePerSeat: true,
          _count: { select: { bookings: true } },
        },
      }),

      // Pending booking requests
      this.prisma.booking.count({
        where: {
          ride: { driverId: driver.id },
          status: 'pending',
        },
      }),

      // Today's earnings
      this.prisma.booking.aggregate({
        where: {
          ride: { driverId: driver.id },
          paymentStatus: 'paid',
          confirmedAt: { gte: today, lt: tomorrow },
        },
        _sum: { totalAmount: true },
      }),

      // Total lifetime earnings
      this.prisma.booking.aggregate({
        where: {
          ride: { driverId: driver.id },
          paymentStatus: 'paid',
        },
        _sum: { totalAmount: true },
      }),

      // Recent 5 bookings
      this.prisma.booking.findMany({
        where: { ride: { driverId: driver.id } },
        orderBy: { bookedAt: 'desc' },
        take: 5,
        select: {
          id: true,
          status: true,
          totalAmount: true,
          bookedAt: true,
          passenger: {
            select: {
              fullName: true,
              profilePhotoUrl: true,
            },
          },
          ride: {
            select: {
              originName: true,
              destName: true,
            },
          },
        },
      }),
    ]);

    return {
      driver: {
        verificationStatus: driver.verificationStatus,
        averageRating: driver.averageRating,
        totalTrips: driver.totalTrips,
        acceptanceRate: driver.acceptanceRate,
        completionRate: driver.completionRate,
      },
      earnings: {
        today: todayEarnings._sum.totalAmount ?? 0,
        lifetime: totalEarnings._sum.totalAmount ?? 0,
      },
      pendingBookingRequests: pendingBookings,
      upcomingTrips,
      recentActivity,
    };
  }
  // ── GET /drivers/:userId/profile ─────────────────────────────
  async getPublicProfile(userId: string) {
    const driver = await this.prisma.driverProfile.findUnique({
      where: { userId },
      select: {
        id: true,
        averageRating: true,
        totalTrips: true,
        acceptanceRate: true,
        completionRate: true,
        verificationStatus: true,
        createdAt: true,
        user: {
          select: {
            id: true,
            fullName: true,
            profilePhotoUrl: true,
          },
        },
        vehicles: {
          where: { isActive: true },
          select: {
            make: true,
            model: true,
            color: true,
            vehicleType: true,
            totalSeats: true,
          },
        },
      },
    });

    if (!driver) {
      throw new NotFoundException('Driver profile not found');
    }

    if (driver.verificationStatus !== 'approved') {
      throw new NotFoundException('Driver profile not found');
    }

    // Get their reviews
    const reviews = await this.prisma.rating.findMany({
      where: {
        rateeId: userId,
        rateeType: 'driver',
      },
      orderBy: { createdAt: 'desc' },
      take: 10,
      select: {
        score: true,
        reviewText: true,
        createdAt: true,
        rater: {
          select: {
            fullName: true,
            profilePhotoUrl: true,
          },
        },
      },
    });

    return {
      id: driver.id,
      fullName: driver.user.fullName,
      profilePhotoUrl: driver.user.profilePhotoUrl,
      averageRating: driver.averageRating,
      totalTrips: driver.totalTrips,
      acceptanceRate: driver.acceptanceRate,
      completionRate: driver.completionRate,
      memberSince: driver.createdAt,
      vehicles: driver.vehicles,
      recentReviews: reviews,
      totalReviews: reviews.length,
    };
  }
}