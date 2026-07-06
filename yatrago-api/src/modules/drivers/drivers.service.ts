import {
  Injectable,
  BadRequestException,
  NotFoundException,
  ConflictException,
  ForbiddenException,
} from '@nestjs/common';
import { PrismaService } from '../../database/prisma.service';
import { AppConfigService } from '../platform/app-config.service';
import { WalletService } from '../platform/wallet.service';
import { NotificationsService } from '../notifications/notifications.service';
import { RequestPayoutDto } from './dto/request-payout.dto';
import { FileSignerService } from '../platform/file-signer.service';
import { EncryptionService } from '../platform/encryption.service';
import { FraudService } from '../platform/fraud.service';
import { StorageService } from '../platform/storage.service';

@Injectable()
export class DriversService {
  constructor(
    private prisma: PrismaService,
    private appConfig: AppConfigService,
    private wallet: WalletService,
    private notifications: NotificationsService,
    private fileSigner: FileSignerService,
    private encryption: EncryptionService,
    private fraud: FraudService,
    private storage: StorageService,
  ) {}

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
    // Stored as a private storage key; clients only ever see signed URLs.
    const fileUrl = `kyc/${file.filename}`;
    await this.storage.persistFromLocal(file.path, fileUrl, file.mimetype);

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
      fileUrl: this.fileSigner.toClientUrl(fileUrl),
    };
  }

  // ── POST /drivers/license ───────────────────────────────────
  async uploadLicense(
    userId: string,
    side: 'front' | 'back',
    file: Express.Multer.File,
    expiryDate?: string,
  ) {
    if (!file) throw new BadRequestException('No file uploaded');

    // Optional expiry date — must parse and must not be in the past
    let parsedExpiry: Date | null = null;
    if (expiryDate !== undefined && expiryDate !== '') {
      parsedExpiry = new Date(expiryDate);
      if (isNaN(parsedExpiry.getTime())) {
        throw new BadRequestException(
          'expiryDate must be a valid ISO date (e.g. 2028-12-31)',
        );
      }
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      if (parsedExpiry < today) {
        throw new BadRequestException('License is expired');
      }
    }

    const driver = await this.getDriverProfile(userId);
    const docType = side === 'front' ? 'license_front' : 'license_back';
    const fileUrl = `kyc/${file.filename}`;
    await this.storage.persistFromLocal(file.path, fileUrl, file.mimetype);

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
        ...(parsedExpiry && { expiryDate: parsedExpiry }),
      },
      update: {
        fileUrl,
        status: 'pending',
        rejectionReason: null,
        ...(parsedExpiry && { expiryDate: parsedExpiry }),
      },
    });

    await this.checkAndUpdateVerificationStatus(driver.id);

    return {
      message: `License ${side} uploaded successfully`,
      docType,
      fileUrl: this.fileSigner.toClientUrl(fileUrl),
    };
  }

  // ── POST /drivers/selfie ────────────────────────────────────
  async uploadSelfie(userId: string, file: Express.Multer.File) {
    if (!file) throw new BadRequestException('No file uploaded');

    const driver = await this.getDriverProfile(userId);
    const fileUrl = `kyc/${file.filename}`;
    await this.storage.persistFromLocal(file.path, fileUrl, file.mimetype);

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
      fileUrl: this.fileSigner.toClientUrl(fileUrl),
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
      status:
        driver.documents.find((d) => d.docType === doc)?.status ??
        'not_uploaded',
      rejectionReason:
        driver.documents.find((d) => d.docType === doc)?.rejectionReason ??
        null,
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

    // Get their reviews (moderated/hidden ratings excluded)
    const reviews = await this.prisma.rating.findMany({
      where: {
        rateeId: userId,
        rateeType: 'driver',
        isHidden: false,
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
  // ── POST /drivers/payouts ────────────────────────────────────
  async requestPayout(userId: string, dto: RequestPayoutDto) {
    const driver = await this.prisma.driverProfile.findUnique({
      where: { userId },
    });
    if (!driver) {
      throw new ForbiddenException(
        'Driver profile not found. Apply as driver first.',
      );
    }
    if (driver.verificationStatus !== 'approved') {
      throw new ForbiddenException(
        `Driver not approved yet. Current status: ${driver.verificationStatus}`,
      );
    }

    const minPayout = await this.appConfig.get('min_payout_npr');
    if (dto.amount < minPayout) {
      throw new BadRequestException(
        `Minimum payout amount is NPR ${minPayout}`,
      );
    }

    // Debit enforces sufficient balance atomically
    await this.wallet.debit(
      userId,
      dto.amount,
      'payout',
      undefined,
      `Payout request via ${dto.method}`,
    );

    // Commission was already deducted at escrow release (trip completion),
    // so the payout carries no additional commission.
    const payout = await this.prisma.payout.create({
      data: {
        driverId: driver.id,
        grossAmount: dto.amount,
        commissionRate: 0,
        commissionAmount: 0,
        netAmount: dto.amount,
        method: dto.method,
        // Bank/wallet account numbers are PII — encrypted at rest.
        accountReference: this.encryption.encrypt(dto.accountReference),
        status: 'pending',
      },
    });

    this.notifications
      .createNotification(
        userId,
        'payout_update',
        'Payout Requested',
        `Your payout request of NPR ${dto.amount} via ${dto.method} has been received and is pending review.`,
        { payoutId: payout.id },
      )
      .catch(() => undefined);

    return { message: 'Payout requested successfully', payout };
  }

  // ── PATCH /drivers/payouts/:id/cancel ────────────────────────
  async cancelPayout(userId: string, payoutId: string) {
    const driver = await this.prisma.driverProfile.findUnique({
      where: { userId },
    });
    if (!driver) {
      throw new ForbiddenException(
        'Driver profile not found. Apply as driver first.',
      );
    }

    const payout = await this.prisma.payout.findUnique({
      where: { id: payoutId },
    });
    if (!payout) throw new NotFoundException('Payout not found');
    if (payout.driverId !== driver.id) {
      throw new ForbiddenException('This payout does not belong to you');
    }
    if (payout.status !== 'pending') {
      throw new BadRequestException(
        `Only pending payouts can be cancelled. Current status: ${payout.status}`,
      );
    }

    await this.prisma.payout.update({
      where: { id: payoutId },
      data: {
        status: 'cancelled',
        failureReason: 'Cancelled by driver',
        processedAt: new Date(),
      },
    });

    // Return the held funds to the driver's wallet
    await this.wallet.credit(
      userId,
      payout.netAmount,
      'payout_reversal',
      payoutId,
      'Payout cancelled by driver',
    );

    return { message: 'Payout cancelled and funds returned to wallet' };
  }

  // ── GET /drivers/payouts ─────────────────────────────────────
  async getPayouts(userId: string) {
    const driver = await this.prisma.driverProfile.findUnique({
      where: { userId },
    });
    if (!driver) {
      throw new ForbiddenException(
        'Driver profile not found. Apply as driver first.',
      );
    }

    const rawPayouts = await this.prisma.payout.findMany({
      where: { driverId: driver.id },
      orderBy: { requestedAt: 'desc' },
    });
    const payouts = rawPayouts.map((p) => ({
      ...p,
      accountReference: p.accountReference
        ? this.encryption.decrypt(p.accountReference)
        : p.accountReference,
    }));

    return { payouts, total: payouts.length };
  }

  async updateLocation(
    userId: string,
    lat: number,
    lng: number,
    isMock = false,
  ) {
    const driver = await this.prisma.driverProfile.findUnique({
      where: { userId },
    });

    if (!driver) {
      throw new NotFoundException('Driver profile not found');
    }

    // GPS integrity: mock-location and impossible-speed jumps raise the
    // fraud score. We still store the point (dropping it would blind
    // support), but the anomaly is recorded for review.
    if (isMock) {
      await this.fraud.record(userId, 'gps_mock', 15, { lat, lng });
    } else if (
      driver.lastLat != null &&
      driver.lastLng != null &&
      driver.lastLocationAt
    ) {
      const km = this.haversineKm(driver.lastLat, driver.lastLng, lat, lng);
      const hours = (Date.now() - driver.lastLocationAt.getTime()) / 3_600_000;
      // Ignore sub-second deltas (division blow-up) and tiny hops.
      if (hours > 0.0006 && km > 1) {
        const speedKmh = km / hours;
        // > 250 km/h between two consumer-GPS pings = teleport/spoof.
        if (speedKmh > 250) {
          await this.fraud.record(userId, 'gps_speed', 20, {
            speedKmh: Math.round(speedKmh),
            km: Math.round(km),
          });
        }
      }
    }

    await this.prisma.driverProfile.update({
      where: { userId },
      data: {
        lastLat: lat,
        lastLng: lng,
        lastLocationAt: new Date(),
      },
    });

    return { success: true };
  }

  // Haversine great-circle distance in km.
  private haversineKm(
    lat1: number,
    lng1: number,
    lat2: number,
    lng2: number,
  ): number {
    const R = 6371;
    const dLat = ((lat2 - lat1) * Math.PI) / 180;
    const dLng = ((lng2 - lng1) * Math.PI) / 180;
    const a =
      Math.sin(dLat / 2) ** 2 +
      Math.cos((lat1 * Math.PI) / 180) *
        Math.cos((lat2 * Math.PI) / 180) *
        Math.sin(dLng / 2) ** 2;
    return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  }
}
