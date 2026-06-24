import {
  Injectable,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { PrismaService } from '../../database/prisma.service';
import { RejectDriverDto } from './dto/reject-driver.dto';

@Injectable()
export class AdminService {
  constructor(private prisma: PrismaService) {}

  // ── GET /admin/dashboard ─────────────────────────────────────
  async getDashboard() {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);

    const [
      totalUsers,
      totalDrivers,
      approvedDrivers,
      pendingDrivers,
      totalTrips,
      tripsToday,
      totalBookings,
      bookingsToday,
      pendingBookings,
      confirmedBookings,
    ] = await Promise.all([
      this.prisma.user.count({ where: { isActive: true } }),
      this.prisma.driverProfile.count(),
      this.prisma.driverProfile.count({
        where: { verificationStatus: 'approved' },
      }),
      this.prisma.driverProfile.count({
        where: { verificationStatus: 'under_review' },
      }),
      this.prisma.ride.count(),
      this.prisma.ride.count({
        where: {
          createdAt: { gte: today, lt: tomorrow },
        },
      }),
      this.prisma.booking.count(),
      this.prisma.booking.count({
        where: {
          bookedAt: { gte: today, lt: tomorrow },
        },
      }),
      this.prisma.booking.count({
        where: { status: 'pending' },
      }),
      this.prisma.booking.count({
        where: { status: 'confirmed' },
      }),
    ]);

    // Revenue — sum of all paid bookings
    const revenueResult = await this.prisma.booking.aggregate({
      where: { paymentStatus: 'paid' },
      _sum: { totalAmount: true },
    });

    const todayRevenueResult = await this.prisma.booking.aggregate({
      where: {
        paymentStatus: 'paid',
        bookedAt: { gte: today, lt: tomorrow },
      },
      _sum: { totalAmount: true },
    });

    return {
      users: {
        total: totalUsers,
      },
      drivers: {
        total: totalDrivers,
        approved: approvedDrivers,
        pendingApproval: pendingDrivers,
      },
      trips: {
        total: totalTrips,
        today: tripsToday,
      },
      bookings: {
        total: totalBookings,
        today: bookingsToday,
        pending: pendingBookings,
        confirmed: confirmedBookings,
      },
      revenue: {
        total: revenueResult._sum.totalAmount ?? 0,
        today: todayRevenueResult._sum.totalAmount ?? 0,
      },
    };
  }

  // ── GET /admin/users ─────────────────────────────────────────
  async getUsers(page = 1, limit = 20, search?: string) {
    const skip = (page - 1) * limit;

    const where = search
      ? {
          OR: [
            { phoneNumber: { contains: search, mode: 'insensitive' as any } },
            { fullName: { contains: search, mode: 'insensitive' as any } },
          ],
        }
      : {};

    const [total, users] = await Promise.all([
      this.prisma.user.count({ where }),
      this.prisma.user.findMany({
        where,
        skip,
        take: limit,
        select: {
          id: true,
          phoneNumber: true,
          fullName: true,
          profilePhotoUrl: true,
          activeMode: true,
          isActive: true,
          isVerified: true,
          createdAt: true,
          driverProfile: {
            select: {
              verificationStatus: true,
              averageRating: true,
              totalTrips: true,
            },
          },
          _count: {
            select: { bookings: true },
          },
        },
        orderBy: { createdAt: 'desc' },
      }),
    ]);

    return {
      users,
      pagination: {
        total,
        page,
        limit,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  // ── GET /admin/drivers ───────────────────────────────────────
  async getDrivers(page = 1, limit = 20, status?: string) {
    const skip = (page - 1) * limit;

    const where = status ? { verificationStatus: status as any } : {};

    const [total, drivers] = await Promise.all([
      this.prisma.driverProfile.count({ where }),
      this.prisma.driverProfile.findMany({
        where,
        skip,
        take: limit,
        include: {
          user: {
            select: {
              id: true,
              phoneNumber: true,
              fullName: true,
              profilePhotoUrl: true,
              createdAt: true,
            },
          },
          documents: {
            select: {
              docType: true,
              status: true,
              fileUrl: true,
              rejectionReason: true,
            },
          },
          vehicles: {
            where: { isActive: true },
            select: {
              make: true,
              model: true,
              plateNumber: true,
              vehicleType: true,
            },
          },
        },
        orderBy: { createdAt: 'desc' },
      }),
    ]);

    return {
      drivers,
      pagination: {
        total,
        page,
        limit,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  // ── GET /admin/trips ─────────────────────────────────────────
  async getTrips(page = 1, limit = 20, status?: string) {
    const skip = (page - 1) * limit;

    const where = status ? { status: status as any } : {};

    const [total, trips] = await Promise.all([
      this.prisma.ride.count({ where }),
      this.prisma.ride.findMany({
        where,
        skip,
        take: limit,
        include: {
          driver: {
            include: {
              user: {
                select: {
                  fullName: true,
                  phoneNumber: true,
                },
              },
            },
          },
          vehicle: {
            select: {
              make: true,
              model: true,
              plateNumber: true,
            },
          },
          _count: {
            select: { bookings: true },
          },
        },
        orderBy: { createdAt: 'desc' },
      }),
    ]);

    return {
      trips,
      pagination: {
        total,
        page,
        limit,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  // ── GET /admin/bookings ──────────────────────────────────────
  async getBookings(page = 1, limit = 20, status?: string) {
    const skip = (page - 1) * limit;

    const where = status ? { status: status as any } : {};

    const [total, bookings] = await Promise.all([
      this.prisma.booking.count({ where }),
      this.prisma.booking.findMany({
        where,
        skip,
        take: limit,
        include: {
          passenger: {
            select: {
              fullName: true,
              phoneNumber: true,
            },
          },
          ride: {
            select: {
              originName: true,
              destName: true,
              departureAt: true,
              pricePerSeat: true,
              driver: {
                select: {
                  user: {
                    select: {
                      fullName: true,
                      phoneNumber: true,
                    },
                  },
                },
              },
            },
          },
        },
        orderBy: { bookedAt: 'desc' },
      }),
    ]);

    return {
      bookings,
      pagination: {
        total,
        page,
        limit,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  // ── PATCH /admin/drivers/:id/approve ─────────────────────────
  async approveDriver(driverProfileId: string) {
    const driver = await this.prisma.driverProfile.findUnique({
      where: { id: driverProfileId },
      include: {
        user: { select: { id: true, fullName: true } },
      },
    });

    if (!driver) throw new NotFoundException('Driver profile not found');

    if (driver.verificationStatus === 'approved') {
      throw new BadRequestException('Driver is already approved');
    }

    await this.prisma.driverProfile.update({
      where: { id: driverProfileId },
      data: {
        verificationStatus: 'approved',
        verifiedAt: new Date(),
        rejectionReason: null,
      },
    });

    // Approve all pending documents
    await this.prisma.driverDocument.updateMany({
      where: { driverId: driverProfileId, status: 'pending' },
      data: { status: 'approved', reviewedAt: new Date() },
    });

    // Send notification to driver
    await this.prisma.notification.create({
      data: {
        userId: driver.userId,
        type: 'system',
        title: 'Driver Application Approved!',
        body: 'Congratulations! Your driver application has been approved. You can now start posting rides.',
        data: {},
      },
    });

    return {
      message: 'Driver approved successfully',
      driverProfileId,
    };
  }

  // ── PATCH /admin/drivers/:id/reject ──────────────────────────
  async rejectDriver(driverProfileId: string, dto: RejectDriverDto) {
    const driver = await this.prisma.driverProfile.findUnique({
      where: { id: driverProfileId },
    });

    if (!driver) throw new NotFoundException('Driver profile not found');

    if (driver.verificationStatus === 'approved') {
      throw new BadRequestException(
        'Cannot reject an already approved driver',
      );
    }

    await this.prisma.driverProfile.update({
      where: { id: driverProfileId },
      data: {
        verificationStatus: 'rejected',
        rejectionReason: dto.reason,
      },
    });

    // Send notification to driver
    await this.prisma.notification.create({
      data: {
        userId: driver.userId,
        type: 'system',
        title: 'Driver Application Update',
        body: `Your application needs attention: ${dto.reason}`,
        data: { reason: dto.reason },
      },
    });

    return {
      message: 'Driver rejected successfully',
      reason: dto.reason,
    };
  }

  // ── PATCH /admin/users/:id/block ─────────────────────────────
  async blockUser(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
    });

    if (!user) throw new NotFoundException('User not found');

    if (!user.isActive) {
      throw new BadRequestException('User is already blocked');
    }

    await this.prisma.user.update({
      where: { id: userId },
      data: { isActive: false },
    });

    return {
      message: 'User blocked successfully',
      userId,
    };
  }
}