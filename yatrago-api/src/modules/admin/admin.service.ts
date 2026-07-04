import {
  Injectable,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { PrismaService } from '../../database/prisma.service';
import { RejectDriverDto } from './dto/reject-driver.dto';
import { RejectPayoutDto } from './dto/reject-payout.dto';
import { UpdateConfigDto } from './dto/update-config.dto';
import { RejectVehicleDto } from './dto/reject-vehicle.dto';
import { OverrideRidePriceDto } from './dto/override-ride-price.dto';
import {
  UpdateReportStatusDto,
  ReportStatusAction,
} from './dto/update-report-status.dto';
import { HideRatingDto } from './dto/hide-rating.dto';
import { CreditWalletDto } from './dto/credit-wallet.dto';
import { CreateAdminDto, GrantableRole } from './dto/create-admin.dto';
import { UpdateAdminRoleDto } from './dto/update-admin-role.dto';
import { AuditService } from '../platform/audit.service';
import { WalletService } from '../platform/wallet.service';
import { SmsService } from '../platform/sms.service';
import {
  AppConfigService,
  CONFIG_DEFAULTS,
  ConfigKey,
} from '../platform/app-config.service';
import { NotificationsService } from '../notifications/notifications.service';
import { renderTemplate } from '../notifications/notification-templates';
import { mergeNotificationSettings } from '../notifications/notification-preferences';

@Injectable()
export class AdminService {
  constructor(
    private prisma: PrismaService,
    private audit: AuditService,
    private wallet: WalletService,
    private appConfig: AppConfigService,
    private notifications: NotificationsService,
    private sms: SmsService,
  ) {}

  // Straight-line distance in km (Haversine) — same helper as
  // trips.service.ts, copied to avoid a cross-module refactor.
  private haversineKm(
    lat1: number,
    lng1: number,
    lat2: number,
    lng2: number,
  ): number {
    const toRad = (deg: number) => (deg * Math.PI) / 180;
    const R = 6371;
    const dLat = toRad(lat2 - lat1);
    const dLng = toRad(lng2 - lng1);
    const a =
      Math.sin(dLat / 2) ** 2 +
      Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
    return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  }

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
  async approveDriver(adminId: string, driverProfileId: string) {
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

    await this.audit.log(adminId, 'driver_approved', 'driver_profile', driverProfileId);

    return {
      message: 'Driver approved successfully',
      driverProfileId,
    };
  }

  // ── PATCH /admin/drivers/:id/reject ──────────────────────────
  async rejectDriver(
    adminId: string,
    driverProfileId: string,
    dto: RejectDriverDto,
  ) {
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

    await this.audit.log(adminId, 'driver_rejected', 'driver_profile', driverProfileId, {
      reason: dto.reason,
    });

    return {
      message: 'Driver rejected successfully',
      reason: dto.reason,
    };
  }

  // ── PATCH /admin/users/:id/block ─────────────────────────────
  async blockUser(adminId: string, userId: string) {
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

    // Force re-login everywhere; the JWT strategy rejects inactive users
    await this.prisma.authSession.deleteMany({ where: { userId } });

    // Cancel the blocked user's active passenger bookings — restore
    // seats, refund fully if paid. The blocked user gets no notification.
    const passengerBookings = await this.prisma.booking.findMany({
      where: {
        passengerId: userId,
        status: { in: ['pending', 'confirmed'] as any },
      },
    });

    for (const booking of passengerBookings) {
      await this.prisma.$transaction(async (tx) => {
        const updated = await tx.booking.updateMany({
          where: {
            id: booking.id,
            status: { in: ['pending', 'confirmed'] as any },
          },
          data: {
            status: 'cancelled' as any,
            cancellationReason: 'Account suspended',
            cancelledAt: new Date(),
            ...(booking.paymentStatus === 'paid' && {
              paymentStatus: 'refunded' as any,
            }),
          },
        });
        if (updated.count === 0) return;

        await tx.ride.update({
          where: { id: booking.rideId },
          data: { availableSeats: { increment: booking.seatsBooked } },
        });
      });

      if (booking.paymentStatus === 'paid' && booking.totalAmount > 0) {
        await this.wallet.credit(
          userId,
          booking.totalAmount,
          'refund',
          booking.id,
          'Full refund — account suspended',
        );
      }
    }

    // If the blocked user is a driver, cancel their published rides and
    // fully refund + notify every affected passenger.
    let cancelledRides = 0;
    const driverProfile = await this.prisma.driverProfile.findUnique({
      where: { userId },
    });

    if (driverProfile) {
      const rides = await this.prisma.ride.findMany({
        where: { driverId: driverProfile.id, status: 'published' as any },
      });

      for (const ride of rides) {
        const affectedBookings = await this.prisma.booking.findMany({
          where: {
            rideId: ride.id,
            status: { in: ['pending', 'confirmed'] as any },
          },
        });

        await this.prisma.$transaction(async (tx) => {
          await tx.ride.update({
            where: { id: ride.id },
            data: { status: 'cancelled' as any },
          });

          await tx.booking.updateMany({
            where: {
              rideId: ride.id,
              status: { in: ['pending', 'confirmed'] as any },
            },
            data: {
              status: 'cancelled' as any,
              cancellationReason: 'Ride cancelled by YatraGo',
              cancelledAt: new Date(),
            },
          });
        });
        cancelledRides++;

        for (const booking of affectedBookings) {
          if (booking.paymentStatus === 'paid' && booking.totalAmount > 0) {
            await this.wallet.credit(
              booking.passengerId,
              booking.totalAmount,
              'refund',
              booking.id,
              'Full refund — ride cancelled by YatraGo',
            );
            await this.prisma.booking.update({
              where: { id: booking.id },
              data: { paymentStatus: 'refunded' as any },
            });
          }

          await this.notifications.createNotification(
            booking.passengerId,
            'booking_rejected',
            'Ride Cancelled',
            `Your ride from ${ride.originName} to ${ride.destName} was cancelled by YatraGo.${booking.paymentStatus === 'paid' ? ' A full refund has been credited to your wallet.' : ''}`,
            { bookingId: booking.id, rideId: ride.id },
          );
        }
      }
    }

    await this.audit.log(adminId, 'user_blocked', 'user', userId, {
      cancelledPassengerBookings: passengerBookings.length,
      cancelledRides,
    });

    return {
      message: 'User blocked successfully',
      userId,
    };
  }

  // ── GET /admin/payouts ───────────────────────────────────────
  async getPayouts(status?: string) {
    const payouts = await this.prisma.payout.findMany({
      where: status ? { status } : {},
      include: {
        driver: {
          include: {
            user: {
              select: {
                id: true,
                fullName: true,
                phoneNumber: true,
                profilePhotoUrl: true,
              },
            },
          },
        },
      },
      orderBy: { requestedAt: 'desc' },
    });

    return { payouts, total: payouts.length };
  }

  // ── PATCH /admin/payouts/:id/approve ─────────────────────────
  async approvePayout(adminId: string, payoutId: string) {
    const payout = await this.prisma.payout.findUnique({
      where: { id: payoutId },
      include: { driver: { select: { userId: true } } },
    });

    if (!payout) throw new NotFoundException('Payout not found');
    if (payout.status !== 'pending') {
      throw new BadRequestException(
        `Only pending payouts can be approved. Current status: ${payout.status}`,
      );
    }

    const updated = await this.prisma.payout.update({
      where: { id: payoutId },
      data: { status: 'completed', processedAt: new Date() },
    });

    await this.notifications.createNotification(
      payout.driver.userId,
      'payout_update',
      'Payout Completed',
      `Your payout of NPR ${payout.netAmount} via ${payout.method} has been processed.`,
      { payoutId },
    );

    await this.audit.log(adminId, 'payout_approved', 'payout', payoutId, {
      amount: payout.netAmount,
      method: payout.method,
    });

    return { message: 'Payout approved successfully', payout: updated };
  }

  // ── PATCH /admin/payouts/:id/reject ──────────────────────────
  async rejectPayout(adminId: string, payoutId: string, dto: RejectPayoutDto) {
    const payout = await this.prisma.payout.findUnique({
      where: { id: payoutId },
      include: { driver: { select: { userId: true } } },
    });

    if (!payout) throw new NotFoundException('Payout not found');
    if (payout.status !== 'pending') {
      throw new BadRequestException(
        `Only pending payouts can be rejected. Current status: ${payout.status}`,
      );
    }

    const updated = await this.prisma.payout.update({
      where: { id: payoutId },
      data: {
        status: 'failed',
        failureReason: dto.reason,
        processedAt: new Date(),
      },
    });

    // Return the withheld funds to the driver's wallet
    await this.wallet.credit(
      payout.driver.userId,
      payout.grossAmount,
      'payout_reversal',
      payoutId,
      `Payout rejected: ${dto.reason}`,
    );

    await this.notifications.createNotification(
      payout.driver.userId,
      'payout_update',
      'Payout Rejected',
      `Your payout of NPR ${payout.grossAmount} was rejected: ${dto.reason}. The amount has been returned to your wallet.`,
      { payoutId },
    );

    await this.audit.log(adminId, 'payout_rejected', 'payout', payoutId, {
      amount: payout.grossAmount,
      reason: dto.reason,
    });

    return { message: 'Payout rejected and funds returned to wallet', payout: updated };
  }

  // ── GET /admin/sos ───────────────────────────────────────────
  async getSosAlerts(status?: string) {
    const alerts = await this.prisma.sosAlert.findMany({
      where: status ? { status: status as any } : {},
      include: {
        user: {
          select: {
            id: true,
            fullName: true,
            phoneNumber: true,
            profilePhotoUrl: true,
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    return { alerts, total: alerts.length };
  }

  // ── PATCH /admin/sos/:id/acknowledge ─────────────────────────
  async acknowledgeSos(adminId: string, sosId: string) {
    const alert = await this.prisma.sosAlert.findUnique({
      where: { id: sosId },
    });

    if (!alert) throw new NotFoundException('SOS alert not found');
    if (alert.status !== 'open') {
      throw new BadRequestException(
        `Only open alerts can be acknowledged. Current status: ${alert.status}`,
      );
    }

    const updated = await this.prisma.sosAlert.update({
      where: { id: sosId },
      data: { status: 'acknowledged' as any },
    });

    await this.audit.log(adminId, 'sos_acknowledged', 'sos_alert', sosId);

    return { message: 'SOS alert acknowledged', alert: updated };
  }

  // ── PATCH /admin/sos/:id/resolve ─────────────────────────────
  async resolveSos(adminId: string, sosId: string) {
    const alert = await this.prisma.sosAlert.findUnique({
      where: { id: sosId },
    });

    if (!alert) throw new NotFoundException('SOS alert not found');
    if (alert.status === 'resolved') {
      throw new BadRequestException('SOS alert is already resolved');
    }

    const updated = await this.prisma.sosAlert.update({
      where: { id: sosId },
      data: { status: 'resolved' as any, resolvedAt: new Date() },
    });

    await this.audit.log(adminId, 'sos_resolved', 'sos_alert', sosId);

    return { message: 'SOS alert resolved', alert: updated };
  }

  // ── GET /admin/audit-logs ────────────────────────────────────
  async getAuditLogs(query: {
    actorId?: string;
    targetType?: string;
    page?: number;
    limit?: number;
  }) {
    const page = query.page && query.page > 0 ? query.page : 1;
    const limit = query.limit && query.limit > 0 ? Math.min(query.limit, 100) : 20;

    const where = {
      ...(query.actorId && { actorId: query.actorId }),
      ...(query.targetType && { targetType: query.targetType }),
    };

    const [total, logs] = await Promise.all([
      this.prisma.auditLog.count({ where }),
      this.prisma.auditLog.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
      }),
    ]);

    return {
      logs,
      pagination: {
        total,
        page,
        limit,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  // ── GET /admin/config ────────────────────────────────────────
  async getConfig() {
    return this.appConfig.getAll();
  }

  // ── PATCH /admin/config ──────────────────────────────────────
  async updateConfig(adminId: string, dto: UpdateConfigDto) {
    if (!(dto.key in CONFIG_DEFAULTS)) {
      throw new BadRequestException(
        `Unknown config key '${dto.key}'. Valid keys: ${Object.keys(CONFIG_DEFAULTS).join(', ')}`,
      );
    }

    await this.appConfig.set(dto.key as ConfigKey, dto.value);

    await this.audit.log(adminId, 'config_updated', 'app_config', dto.key, {
      key: dto.key,
      value: dto.value,
    });

    return { message: 'Config updated successfully', key: dto.key, value: dto.value };
  }

  // ── POST /admin/wallets/:userId/credit ───────────────────────
  // Fund a driver's wallet. Since passenger gateways were removed, this is the
  // money-in path for driver top-ups (until a real PSP is integrated).
  async creditWallet(adminId: string, userId: string, dto: CreditWalletDto) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new NotFoundException('User not found');

    await this.wallet.credit(
      userId,
      dto.amount,
      'topup',
      undefined,
      dto.note ?? 'Admin wallet credit',
    );

    await this.notifications.createNotification(
      userId,
      'wallet_topup',
      'Wallet Topped Up',
      `NPR ${dto.amount} has been added to your wallet.`,
      { amount: dto.amount },
    );

    await this.audit.log(adminId, 'wallet_credited', 'wallet', userId, {
      amount: dto.amount,
      note: dto.note,
    });

    const { balance } = await this.wallet.getBalance(userId);
    return { message: 'Wallet credited successfully', userId, balance };
  }

  // ── PATCH /admin/rides/:id/cancel ────────────────────────────
  async forceCancelRide(adminId: string, rideId: string) {
    const ride = await this.prisma.ride.findUnique({
      where: { id: rideId },
      include: { driver: { select: { userId: true } } },
    });

    if (!ride) throw new NotFoundException('Ride not found');
    if (ride.status !== 'published' && ride.status !== 'in_progress') {
      throw new BadRequestException(
        `Only published or in-progress rides can be force-cancelled. Current status: ${ride.status}`,
      );
    }

    // Snapshot affected bookings before cancelling
    const affectedBookings = await this.prisma.booking.findMany({
      where: {
        rideId,
        status: { in: ['pending', 'confirmed'] as any },
      },
      include: {
        passenger: {
          select: { phoneNumber: true, notificationSettings: true },
        },
      },
    });

    await this.prisma.$transaction(async (tx) => {
      await tx.ride.update({
        where: { id: rideId },
        data: { status: 'cancelled' as any },
      });

      await tx.booking.updateMany({
        where: {
          rideId,
          status: { in: ['pending', 'confirmed'] as any },
        },
        data: {
          status: 'cancelled' as any,
          cancellationReason: 'Cancelled by YatraGo admin',
          cancelledAt: new Date(),
        },
      });
    });

    // Full refund to every paid passenger + notify all affected passengers
    let refundedCount = 0;
    for (const booking of affectedBookings) {
      if (booking.paymentStatus === 'paid' && booking.totalAmount > 0) {
        await this.wallet.credit(
          booking.passengerId,
          booking.totalAmount,
          'refund',
          booking.id,
          'Full refund — ride cancelled by YatraGo admin',
        );
        await this.prisma.booking.update({
          where: { id: booking.id },
          data: { paymentStatus: 'refunded' as any },
        });
        refundedCount++;
      }

      await this.notifications.createNotification(
        booking.passengerId,
        'booking_rejected',
        'Ride Cancelled',
        `Your ride from ${ride.originName} to ${ride.destName} was cancelled by YatraGo.${booking.paymentStatus === 'paid' ? ' A full refund has been credited to your wallet.' : ''}`,
        { bookingId: booking.id, rideId },
      );

      // SMS fallback for paid passengers (skipped if bookings muted)
      if (
        booking.paymentStatus === 'paid' &&
        mergeNotificationSettings(booking.passenger.notificationSettings)
          .bookings
      ) {
        const sms = renderTemplate('ride_cancelled_by_admin', {
          origin: ride.originName,
          dest: ride.destName,
          refunded: 'true',
        });
        this.sms
          .send(booking.passenger.phoneNumber, sms.body)
          .catch(() => undefined);
      }
    }

    // Notify the driver too
    await this.notifications.createNotification(
      ride.driver.userId,
      'system',
      'Ride Cancelled by Admin',
      `Your ride from ${ride.originName} to ${ride.destName} was cancelled by YatraGo.`,
      { rideId },
    );

    await this.audit.log(adminId, 'ride_force_cancelled', 'ride', rideId, {
      affectedBookings: affectedBookings.length,
      refundedBookings: refundedCount,
    });

    return {
      message: 'Ride force-cancelled successfully',
      rideId,
      cancelledBookings: affectedBookings.length,
      refundedBookings: refundedCount,
    };
  }

  // ── GET /admin/vehicles ──────────────────────────────────────
  async getVehicles(status?: string) {
    const where =
      status === 'active'
        ? { isActive: true }
        : status === 'inactive'
          ? { isActive: false }
          : {};

    const vehicles = await this.prisma.vehicle.findMany({
      where,
      include: {
        driver: {
          include: {
            user: {
              select: {
                id: true,
                fullName: true,
                phoneNumber: true,
                profilePhotoUrl: true,
              },
            },
          },
        },
        documents: {
          select: { docType: true, fileUrl: true, status: true },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    return { vehicles, total: vehicles.length };
  }

  // ── PATCH /admin/vehicles/:id/approve ────────────────────────
  async approveVehicle(adminId: string, vehicleId: string) {
    const vehicle = await this.prisma.vehicle.findUnique({
      where: { id: vehicleId },
      include: { driver: { select: { userId: true } } },
    });

    if (!vehicle) throw new NotFoundException('Vehicle not found');

    await this.prisma.vehicle.update({
      where: { id: vehicleId },
      data: { isActive: true },
    });

    await this.notifications.createNotification(
      vehicle.driver.userId,
      'system',
      'Vehicle Approved',
      `Your vehicle ${vehicle.make} ${vehicle.model} (${vehicle.plateNumber}) has been approved. You can now use it for rides.`,
      { vehicleId },
    );

    await this.audit.log(adminId, 'vehicle_approved', 'vehicle', vehicleId);

    return { message: 'Vehicle approved successfully', vehicleId };
  }

  // ── PATCH /admin/vehicles/:id/reject ─────────────────────────
  async rejectVehicle(
    adminId: string,
    vehicleId: string,
    dto: RejectVehicleDto,
  ) {
    const vehicle = await this.prisma.vehicle.findUnique({
      where: { id: vehicleId },
      include: { driver: { select: { userId: true } } },
    });

    if (!vehicle) throw new NotFoundException('Vehicle not found');

    await this.prisma.vehicle.update({
      where: { id: vehicleId },
      data: { isActive: false },
    });

    await this.notifications.createNotification(
      vehicle.driver.userId,
      'system',
      'Vehicle Rejected',
      `Your vehicle ${vehicle.make} ${vehicle.model} (${vehicle.plateNumber}) was not approved: ${dto.reason}`,
      { vehicleId, reason: dto.reason },
    );

    await this.audit.log(adminId, 'vehicle_rejected', 'vehicle', vehicleId, {
      reason: dto.reason,
    });

    return { message: 'Vehicle rejected successfully', vehicleId, reason: dto.reason };
  }

  // ── PATCH /admin/rides/:id/price ─────────────────────────────
  async overrideRidePrice(
    adminId: string,
    rideId: string,
    dto: OverrideRidePriceDto,
  ) {
    const ride = await this.prisma.ride.findUnique({
      where: { id: rideId },
      include: { driver: { select: { userId: true } } },
    });

    if (!ride) throw new NotFoundException('Ride not found');
    if (ride.status !== 'published') {
      throw new BadRequestException(
        `Only published rides can have their price overridden. Current status: ${ride.status}`,
      );
    }

    // Same price-cap rule as ride creation
    const routeKm = this.haversineKm(
      ride.originLat,
      ride.originLng,
      ride.destLat,
      ride.destLng,
    );
    const priceCapPerKm = await this.appConfig.get('price_cap_per_km');
    const maxPrice = Math.ceil(routeKm * priceCapPerKm);
    if (dto.pricePerSeat > maxPrice) {
      throw new BadRequestException(
        `Price per seat cannot exceed NPR ${maxPrice} for this route (${Math.round(routeKm)} km at NPR ${priceCapPerKm}/km)`,
      );
    }

    const oldPrice = ride.pricePerSeat;

    // Existing bookings keep their totalAmount; only future bookings
    // are priced at the new rate.
    const updated = await this.prisma.ride.update({
      where: { id: rideId },
      data: { pricePerSeat: dto.pricePerSeat },
    });

    await this.notifications.createNotification(
      ride.driver.userId,
      'system',
      'Ride Price Adjusted',
      `The price per seat for your ride from ${ride.originName} to ${ride.destName} was adjusted by YatraGo from NPR ${oldPrice} to NPR ${dto.pricePerSeat}.`,
      { rideId, oldPrice, newPrice: dto.pricePerSeat },
    );

    await this.audit.log(adminId, 'ride_price_overridden', 'ride', rideId, {
      oldPrice,
      newPrice: dto.pricePerSeat,
    });

    return {
      message: 'Ride price overridden successfully',
      ride: updated,
      oldPrice,
      newPrice: dto.pricePerSeat,
    };
  }

  // ── GET /admin/reports ───────────────────────────────────────
  async getReports(status?: string) {
    const reports = await this.prisma.userReport.findMany({
      where: status ? { status: status as any } : {},
      include: {
        reporter: {
          select: { id: true, fullName: true, phoneNumber: true },
        },
        reported: {
          select: { id: true, fullName: true, phoneNumber: true },
        },
        booking: {
          select: {
            id: true,
            status: true,
            ride: {
              select: { originName: true, destName: true, departureAt: true },
            },
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    return { reports, total: reports.length };
  }

  // ── PATCH /admin/reports/:id/status ──────────────────────────
  async updateReportStatus(
    adminId: string,
    reportId: string,
    dto: UpdateReportStatusDto,
  ) {
    const report = await this.prisma.userReport.findUnique({
      where: { id: reportId },
    });

    if (!report) throw new NotFoundException('Report not found');

    const resolved =
      dto.status === ReportStatusAction.resolved ||
      dto.status === ReportStatusAction.dismissed;

    const updated = await this.prisma.userReport.update({
      where: { id: reportId },
      data: {
        status: dto.status as any,
        ...(resolved && { resolvedAt: new Date() }),
      },
    });

    await this.audit.log(
      adminId,
      'report_status_updated',
      'user_report',
      reportId,
      { status: dto.status },
    );

    return { message: 'Report status updated', report: updated };
  }

  // ── PATCH /admin/ratings/:id/hide ────────────────────────────
  async hideRating(adminId: string, ratingId: string, dto: HideRatingDto) {
    const rating = await this.prisma.rating.findUnique({
      where: { id: ratingId },
    });

    if (!rating) throw new NotFoundException('Rating not found');
    if (rating.isHidden) {
      throw new BadRequestException('Rating is already hidden');
    }

    await this.prisma.rating.update({
      where: { id: ratingId },
      data: { isHidden: true, flagReason: dto.reason },
    });

    await this.recalculateAverageRating(rating.rateeId, rating.rateeType);

    await this.audit.log(adminId, 'rating_hidden', 'rating', ratingId, {
      reason: dto.reason,
    });

    return { message: 'Rating hidden successfully', ratingId };
  }

  // ── PATCH /admin/ratings/:id/unhide ──────────────────────────
  async unhideRating(adminId: string, ratingId: string) {
    const rating = await this.prisma.rating.findUnique({
      where: { id: ratingId },
    });

    if (!rating) throw new NotFoundException('Rating not found');
    if (!rating.isHidden) {
      throw new BadRequestException('Rating is not hidden');
    }

    await this.prisma.rating.update({
      where: { id: ratingId },
      data: { isHidden: false, flagReason: null },
    });

    await this.recalculateAverageRating(rating.rateeId, rating.rateeType);

    await this.audit.log(adminId, 'rating_unhidden', 'rating', ratingId);

    return { message: 'Rating unhidden successfully', ratingId };
  }

  // ── GET /admin/admins ────────────────────────────────────────
  // Roster of everyone with admin or super_admin rights.
  async getAdmins() {
    const admins = await this.prisma.user.findMany({
      where: { role: { in: ['admin', 'super_admin'] } },
      select: {
        id: true,
        fullName: true,
        phoneNumber: true,
        profilePhotoUrl: true,
        role: true,
        isActive: true,
        createdAt: true,
      },
      orderBy: [{ role: 'desc' }, { createdAt: 'asc' }],
    });
    return { admins, total: admins.length };
  }

  // ── POST /admin/admins ───────────────────────────────────────
  // Grant admin (or super_admin) rights to an existing user by phone.
  async addAdmin(actorId: string, dto: CreateAdminDto) {
    const role = dto.role ?? GrantableRole.admin;

    const user = await this.prisma.user.findUnique({
      where: { phoneNumber: dto.phoneNumber },
    });
    if (!user) {
      throw new NotFoundException(
        'No user with that phone number. They must sign up (log in once) before being made an admin.',
      );
    }
    if (user.role === role) {
      throw new BadRequestException(`User is already a ${role}.`);
    }

    const updated = await this.prisma.user.update({
      where: { id: user.id },
      data: { role: role as any },
      select: { id: true, fullName: true, phoneNumber: true, role: true },
    });

    await this.notifications.createNotification(
      user.id,
      'system',
      'Admin Access Granted',
      `You have been granted ${role.replace('_', ' ')} access to the YatraGo console.`,
      { role },
    );

    await this.audit.log(actorId, 'admin_granted', 'user', user.id, { role });

    return { message: 'Admin access granted', admin: updated };
  }

  // ── PATCH /admin/admins/:userId/role ─────────────────────────
  async updateAdminRole(
    actorId: string,
    targetUserId: string,
    dto: UpdateAdminRoleDto,
  ) {
    if (actorId === targetUserId) {
      throw new BadRequestException('You cannot change your own role.');
    }

    const target = await this.prisma.user.findUnique({
      where: { id: targetUserId },
    });
    if (!target) throw new NotFoundException('User not found');
    if (target.role !== 'admin' && target.role !== 'super_admin') {
      throw new BadRequestException('Target user is not an admin.');
    }
    if (target.role === dto.role) {
      throw new BadRequestException(`User is already a ${dto.role}.`);
    }

    // Never leave the platform without a super admin.
    if (target.role === 'super_admin' && dto.role !== GrantableRole.super_admin) {
      await this.assertNotLastSuperAdmin(targetUserId);
    }

    const updated = await this.prisma.user.update({
      where: { id: targetUserId },
      data: { role: dto.role as any },
      select: { id: true, fullName: true, phoneNumber: true, role: true },
    });

    await this.audit.log(actorId, 'admin_role_updated', 'user', targetUserId, {
      role: dto.role,
    });

    return { message: 'Admin role updated', admin: updated };
  }

  // ── DELETE /admin/admins/:userId ─────────────────────────────
  // Revoke all admin rights — the user reverts to a normal account.
  async revokeAdmin(actorId: string, targetUserId: string) {
    if (actorId === targetUserId) {
      throw new BadRequestException('You cannot revoke your own admin access.');
    }

    const target = await this.prisma.user.findUnique({
      where: { id: targetUserId },
    });
    if (!target) throw new NotFoundException('User not found');
    if (target.role !== 'admin' && target.role !== 'super_admin') {
      throw new BadRequestException('Target user is not an admin.');
    }

    if (target.role === 'super_admin') {
      await this.assertNotLastSuperAdmin(targetUserId);
    }

    await this.prisma.user.update({
      where: { id: targetUserId },
      data: { role: 'user' as any },
    });

    await this.notifications.createNotification(
      targetUserId,
      'system',
      'Admin Access Revoked',
      'Your admin access to the YatraGo console has been removed.',
      {},
    );

    await this.audit.log(actorId, 'admin_revoked', 'user', targetUserId);

    return { message: 'Admin access revoked', userId: targetUserId };
  }

  // Guard against demoting/removing the final super admin, which would lock
  // everyone out of admin-roster management.
  private async assertNotLastSuperAdmin(excludingUserId: string) {
    const remaining = await this.prisma.user.count({
      where: { role: 'super_admin', id: { not: excludingUserId } },
    });
    if (remaining === 0) {
      throw new BadRequestException(
        'Cannot remove the last super admin. Promote another super admin first.',
      );
    }
  }

  // ── Helper: recalculate average excluding hidden ratings ─────
  // Mirrors ReviewsService.updateAverageRating (hidden ratings excluded).
  private async recalculateAverageRating(rateeId: string, rateeType: string) {
    if (rateeType !== 'driver') return; // only drivers store an average

    const visibleRatings = await this.prisma.rating.findMany({
      where: { rateeId, isHidden: false },
      select: { score: true },
    });

    const average =
      visibleRatings.length > 0
        ? visibleRatings.reduce((sum, r) => sum + r.score, 0) /
          visibleRatings.length
        : 0;
    const rounded = Math.round(average * 100) / 100;

    const driverProfile = await this.prisma.driverProfile.findUnique({
      where: { userId: rateeId },
    });
    if (driverProfile) {
      await this.prisma.driverProfile.update({
        where: { id: driverProfile.id },
        data: { averageRating: rounded },
      });
    }
  }
}