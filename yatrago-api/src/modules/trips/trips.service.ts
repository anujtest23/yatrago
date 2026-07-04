import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
} from '@nestjs/common';
import { PrismaService } from '../../database/prisma.service';
import { AppConfigService } from '../platform/app-config.service';
import { WalletService } from '../platform/wallet.service';
import { SmsService } from '../platform/sms.service';
import { renderTemplate } from '../notifications/notification-templates';
import { mergeNotificationSettings } from '../notifications/notification-preferences';
import { CreateTripDto } from './dto/create-trip.dto';
import { UpdateTripDto } from './dto/update-trip.dto';

@Injectable()
export class TripsService {
  constructor(
    private prisma: PrismaService,
    private appConfig: AppConfigService,
    private wallet: WalletService,
    private sms: SmsService,
  ) {}

  // Straight-line distance in km (Haversine)
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

  // ── Helper: get driver profile ───────────────────────────────
  private async getDriverProfile(userId: string) {
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
    return driver;
  }

  // ── Helper: verify trip belongs to driver ────────────────────
  private async getTripOrThrow(tripId: string, driverId: string) {
    const trip = await this.prisma.ride.findUnique({
      where: { id: tripId },
    });
    if (!trip) throw new NotFoundException('Trip not found');
    if (trip.driverId !== driverId) {
      throw new ForbiddenException('This trip does not belong to you');
    }
    return trip;
  }

  // ── POST /trips ──────────────────────────────────────────────
  async create(userId: string, dto: CreateTripDto) {
    const driver = await this.getDriverProfile(userId);

    // Verify vehicle belongs to this driver
    const vehicle = await this.prisma.vehicle.findUnique({
      where: { id: dto.vehicleId },
    });
    if (!vehicle || vehicle.driverId !== driver.id) {
      throw new ForbiddenException('Vehicle not found or does not belong to you');
    }

    // Vehicle must be admin-approved (isActive) to be used for rides
    if (!vehicle.isActive) {
      throw new ForbiddenException(
        'This vehicle has not been approved for rides',
      );
    }

    // Driver must hold the minimum wallet balance to post rides (the platform
    // recovers its commission from this wallet after ride completion).
    const minBalance = await this.appConfig.get('min_wallet_balance');
    await this.wallet.assertMinBalance(userId, minBalance);

    // Seat limit: driver occupies one seat of the vehicle
    const maxBookableSeats = vehicle.totalSeats - 1;
    if (dto.totalSeats > maxBookableSeats) {
      throw new BadRequestException(
        `Seats cannot exceed ${maxBookableSeats} for this vehicle (driver occupies one seat)`,
      );
    }

    // Departure window: not too soon, not too far out
    const departureAt = new Date(dto.departureAt);
    const minDepartureMinutes = await this.appConfig.get(
      'min_departure_minutes',
    );
    const maxDepartureDays = await this.appConfig.get('max_departure_days');

    const minDeparture = new Date(Date.now() + minDepartureMinutes * 60_000);
    const maxDeparture = new Date(
      Date.now() + maxDepartureDays * 24 * 60 * 60_000,
    );

    if (departureAt < minDeparture) {
      throw new BadRequestException(
        `Departure must be at least ${minDepartureMinutes} minutes from now`,
      );
    }
    if (departureAt > maxDeparture) {
      throw new BadRequestException(
        `Departure cannot be more than ${maxDepartureDays} days from now`,
      );
    }

    // Origin and destination must be distinct places
    const routeKm = this.haversineKm(
      dto.originLat,
      dto.originLng,
      dto.destLat,
      dto.destLng,
    );
    if (routeKm < 1) {
      throw new BadRequestException(
        'Origin and destination must be different locations',
      );
    }

    // Price cap: per-seat price must not exceed distance × admin cap
    const priceCapPerKm = await this.appConfig.get('price_cap_per_km');
    const maxPrice = Math.ceil(routeKm * priceCapPerKm);
    if (dto.pricePerSeat > maxPrice) {
      throw new BadRequestException(
        `Price per seat cannot exceed NPR ${maxPrice} for this route (${Math.round(routeKm)} km at NPR ${priceCapPerKm}/km)`,
      );
    }

    const trip = await this.prisma.ride.create({
      data: {
        driverId: driver.id,
        vehicleId: dto.vehicleId,
        originName: dto.originName,
        originLat: dto.originLat,
        originLng: dto.originLng,
        originCity: dto.originCity,
        originState: dto.originState,
        destName: dto.destName,
        destLat: dto.destLat,
        destLng: dto.destLng,
        destCity: dto.destCity,
        destState: dto.destState,
        departureAt,
        totalSeats: dto.totalSeats,
        availableSeats: dto.totalSeats,
        pricePerSeat: dto.pricePerSeat,
        womenOnly: dto.womenOnly ?? false,
        smokingPref: (dto.smokingPref as any) ?? 'no_smoking',
        luggagePref: (dto.luggagePref as any) ?? 'any',
        notes: dto.notes,
        stops: dto.stops
          ? {
              create: dto.stops.map((stop) => ({
                locationName: stop.locationName,
                lat: stop.lat,
                lng: stop.lng,
                stopOrder: stop.stopOrder,
                minutesFromStart: stop.minutesFromStart,
              })),
            }
          : undefined,
      },
      include: {
        stops: { orderBy: { stopOrder: 'asc' } },
        vehicle: {
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

    return { message: 'Ride published successfully', trip };
  }

  // ── GET /trips ───────────────────────────────────────────────
  async findAll(userId: string, status?: string) {
    const driver = await this.prisma.driverProfile.findUnique({
      where: { userId },
    });
    if (!driver) throw new ForbiddenException('Driver profile not found');

    const trips = await this.prisma.ride.findMany({
      where: {
        driverId: driver.id,
        ...(status && { status: status as any }),
      },
      include: {
        stops: { orderBy: { stopOrder: 'asc' } },
        vehicle: {
          select: {
            make: true,
            model: true,
            color: true,
            plateNumber: true,
          },
        },
        _count: {
          select: { bookings: true },
        },
      },
      orderBy: { departureAt: 'asc' },
    });

    return { trips, total: trips.length };
  }

  // ── GET /trips/:id ───────────────────────────────────────────
  async findOne(userId: string, tripId: string) {
    const driver = await this.prisma.driverProfile.findUnique({
      where: { userId },
    });
    if (!driver) throw new ForbiddenException('Driver profile not found');

    await this.getTripOrThrow(tripId, driver.id);

    return this.prisma.ride.findUnique({
      where: { id: tripId },
      include: {
        stops: { orderBy: { stopOrder: 'asc' } },
        vehicle: true,
        bookings: {
          where: { status: { in: ['confirmed', 'pending'] } },
          include: {
            passenger: {
              select: {
                id: true,
                fullName: true,
                profilePhotoUrl: true,
                phoneNumber: true,
              },
            },
          },
        },
      },
    });
  }

  // ── PATCH /trips/:id ─────────────────────────────────────────
  async update(userId: string, tripId: string, dto: UpdateTripDto) {
    const driver = await this.getDriverProfile(userId);
    const trip = await this.getTripOrThrow(tripId, driver.id);

    // Can only edit published trips
    if (trip.status !== 'published') {
      throw new BadRequestException(
        'Only published trips can be edited',
      );
    }

    // Same departure-window rules as trip creation
    if (dto.departureAt) {
      const newDeparture = new Date(dto.departureAt);
      const minDepartureMinutes = await this.appConfig.get(
        'min_departure_minutes',
      );
      const maxDepartureDays = await this.appConfig.get('max_departure_days');

      if (
        newDeparture < new Date(Date.now() + minDepartureMinutes * 60_000)
      ) {
        throw new BadRequestException(
          `Departure must be at least ${minDepartureMinutes} minutes from now`,
        );
      }
      if (
        newDeparture >
        new Date(Date.now() + maxDepartureDays * 24 * 60 * 60_000)
      ) {
        throw new BadRequestException(
          `Departure cannot be more than ${maxDepartureDays} days from now`,
        );
      }
    }

    // Same price-cap rule as trip creation (route is fixed, so use stored coords)
    if (dto.pricePerSeat !== undefined) {
      const routeKm = this.haversineKm(
        trip.originLat,
        trip.originLng,
        trip.destLat,
        trip.destLng,
      );
      const priceCapPerKm = await this.appConfig.get('price_cap_per_km');
      const maxPrice = Math.ceil(routeKm * priceCapPerKm);
      if (dto.pricePerSeat > maxPrice) {
        throw new BadRequestException(
          `Price per seat cannot exceed NPR ${maxPrice} for this route`,
        );
      }
    }

    const updated = await this.prisma.ride.update({
      where: { id: tripId },
      data: {
        ...(dto.departureAt && { departureAt: new Date(dto.departureAt) }),
        ...(dto.totalSeats && {
          totalSeats: dto.totalSeats,
          availableSeats: dto.totalSeats - (trip.totalSeats - trip.availableSeats),
        }),
        ...(dto.pricePerSeat !== undefined && { pricePerSeat: dto.pricePerSeat }),
        ...(dto.womenOnly !== undefined && { womenOnly: dto.womenOnly }),
        ...(dto.smokingPref && { smokingPref: dto.smokingPref as any }),
        ...(dto.luggagePref && { luggagePref: dto.luggagePref as any }),
        ...(dto.notes !== undefined && { notes: dto.notes }),
      },
      include: {
        stops: { orderBy: { stopOrder: 'asc' } },
      },
    });

    return { message: 'Trip updated successfully', trip: updated };
  }

  // ── DELETE /trips/:id ────────────────────────────────────────
  async remove(userId: string, tripId: string) {
    const driver = await this.getDriverProfile(userId);
    const trip = await this.getTripOrThrow(tripId, driver.id);

    if (trip.status === 'in_progress') {
      throw new BadRequestException('Cannot cancel a trip that is in progress');
    }

    if (trip.status === 'completed') {
      throw new BadRequestException('Cannot cancel a completed trip');
    }

    // Snapshot affected bookings before cancelling
    const affectedBookings = await this.prisma.booking.findMany({
      where: {
        rideId: tripId,
        status: { in: ['pending', 'confirmed'] },
      },
      include: {
        passenger: {
          select: { phoneNumber: true, notificationSettings: true },
        },
      },
    });

    await this.prisma.$transaction(async (tx) => {
      await tx.ride.update({
        where: { id: tripId },
        data: { status: 'cancelled' },
      });

      await tx.booking.updateMany({
        where: {
          rideId: tripId,
          status: { in: ['pending', 'confirmed'] },
        },
        data: {
          status: 'cancelled',
          cancellationReason: 'Trip cancelled by driver',
          cancelledAt: new Date(),
        },
      });

      // Track driver cancellations for trust scoring
      await tx.driverProfile.update({
        where: { id: driver.id },
        data: { cancellationRate: { increment: 1 } },
      });
    });

    // Driver cancellation → full refund to every paid passenger (to wallet)
    for (const booking of affectedBookings) {
      if (booking.paymentStatus === 'paid' && booking.totalAmount > 0) {
        await this.wallet.credit(
          booking.passengerId,
          booking.totalAmount,
          'refund',
          booking.id,
          'Full refund — ride cancelled by driver',
        );
        await this.prisma.booking.update({
          where: { id: booking.id },
          data: { paymentStatus: 'refunded' },
        });
      }

      await this.prisma.notification.create({
        data: {
          userId: booking.passengerId,
          type: 'booking_rejected',
          title: 'Ride Cancelled',
          body: `Your ride from ${trip.originName} to ${trip.destName} was cancelled by the driver.${booking.paymentStatus === 'paid' ? ' A full refund has been credited to your wallet.' : ''}`,
          data: { bookingId: booking.id, tripId },
        },
      });

      // SMS fallback for paid passengers (skipped if bookings muted)
      if (
        booking.paymentStatus === 'paid' &&
        mergeNotificationSettings(booking.passenger.notificationSettings)
          .bookings
      ) {
        const sms = renderTemplate('ride_cancelled_by_driver', {
          origin: trip.originName,
          dest: trip.destName,
          refunded: 'true',
        });
        this.sms
          .send(booking.passenger.phoneNumber, sms.body)
          .catch(() => undefined);
      }
    }

    return {
      message: 'Trip cancelled successfully',
      refundedBookings: affectedBookings.filter(
        (b) => b.paymentStatus === 'paid',
      ).length,
    };
  }
  // ── PATCH /trips/:id/start ───────────────────────────────────
  async startTrip(userId: string, tripId: string) {
    const driver = await this.getDriverProfile(userId);
    const trip = await this.getTripOrThrow(tripId, driver.id);

    if (trip.status !== 'published') {
      throw new BadRequestException(
        `Cannot start a trip with status: ${trip.status}`,
      );
    }

    // Must have at least one confirmed booking
    const confirmedBookings = await this.prisma.booking.count({
      where: { rideId: tripId, status: 'confirmed' },
    });

    if (confirmedBookings === 0) {
      throw new BadRequestException(
        'Cannot start a trip with no confirmed passengers',
      );
    }

    await this.prisma.ride.update({
      where: { id: tripId },
      data: {
        status: 'in_progress',
        startedAt: new Date(),
      },
    });

    // Notify all confirmed passengers
    const bookings = await this.prisma.booking.findMany({
      where: { rideId: tripId, status: 'confirmed' },
      select: { passengerId: true },
    });

    await Promise.all(
      bookings.map((b) =>
        this.prisma.notification.create({
          data: {
            userId: b.passengerId,
            type: 'trip_started',
            title: 'Your trip has started!',
            body: `Your ride from ${trip.originName} to ${trip.destName} is now in progress.`,
            data: { tripId },
          },
        }),
      ),
    );

    return { message: 'Trip started successfully', tripId, status: 'in_progress' };
  }

  // ── PATCH /trips/:id/complete ────────────────────────────────
  async completeTrip(userId: string, tripId: string) {
    const driver = await this.getDriverProfile(userId);
    const trip = await this.getTripOrThrow(tripId, driver.id);

    if (trip.status !== 'in_progress') {
      throw new BadRequestException(
        `Cannot complete a trip with status: ${trip.status}`,
      );
    }

    await this.prisma.$transaction(async (tx) => {
      // Mark trip completed
      await tx.ride.update({
        where: { id: tripId },
        data: {
          status: 'completed',
          completedAt: new Date(),
        },
      });

      // Mark all confirmed bookings as completed
      await tx.booking.updateMany({
        where: {
          rideId: tripId,
          status: 'confirmed',
        },
        data: {
          status: 'completed',
          completedAt: new Date(),
        },
      });

      // Update driver total trips count
      await tx.driverProfile.update({
        where: { id: driver.id },
        data: {
          totalTrips: { increment: 1 },
          completionRate: { increment: 1 },
        },
      });
    });

    // Get confirmed passengers to notify
    const bookings = await this.prisma.booking.findMany({
      where: { rideId: tripId, status: 'completed' },
      select: {
        passengerId: true,
        id: true,
        totalAmount: true,
      },
    });

    // Platform commission — passengers pay the driver directly (off-app), so
    // the platform earns by DEBITING commission from the driver's wallet once
    // the ride completes. Configurable: percentage of fares, or a fixed fee.
    const grossFares = bookings.reduce((sum, b) => sum + b.totalAmount, 0);
    const commissionMode = await this.appConfig.get('commission_mode');
    const commissionPercent = await this.appConfig.get('commission_percent');
    const commissionFixed = await this.appConfig.get('commission_fixed');
    const minBalance = await this.appConfig.get('min_wallet_balance');

    const commissionAmount =
      commissionMode === 1
        ? commissionFixed
        : Math.round(grossFares * (commissionPercent / 100) * 100) / 100;

    if (commissionAmount > 0) {
      let commissionStatus = 'charged';
      try {
        await this.wallet.debit(
          userId, // completeTrip caller is the driver's user
          commissionAmount,
          'commission',
          tripId,
          commissionMode === 1
            ? `Platform commission (fixed NPR ${commissionFixed}) for ride ${tripId}`
            : `Platform commission (${commissionPercent}% of NPR ${grossFares}) for ride ${tripId}`,
        );
      } catch {
        // Insufficient balance — record the debt instead of blocking completion.
        commissionStatus = 'owed';
      }

      await this.prisma.commissionRecord.create({
        data: {
          rideId: tripId,
          driverId: driver.id,
          mode: commissionMode === 1 ? 'fixed' : 'percent',
          rate: commissionMode === 1 ? 0 : commissionPercent,
          grossFares,
          amount: commissionAmount,
          status: commissionStatus,
        },
      });

      // Notify the driver of the deduction (or the owed debt).
      await this.prisma.notification.create({
        data: {
          userId,
          type: commissionStatus === 'owed' ? 'wallet_low' : 'commission_charged',
          title:
            commissionStatus === 'owed'
              ? 'Wallet Balance Too Low'
              : 'Commission Deducted',
          body:
            commissionStatus === 'owed'
              ? `NPR ${commissionAmount} commission could not be charged — your wallet balance is too low. Please top up.`
              : `NPR ${commissionAmount} platform commission was deducted from your wallet for your completed ride.`,
          data: { tripId, amount: commissionAmount },
        },
      });

      // Low-balance warning after a successful deduction.
      if (commissionStatus === 'charged') {
        const { balance } = await this.wallet.getBalance(userId);
        if (balance < minBalance) {
          await this.prisma.notification.create({
            data: {
              userId,
              type: 'wallet_low',
              title: 'Wallet Balance Low',
              body: `Your wallet balance (NPR ${balance}) is below the minimum NPR ${minBalance}. Top up to keep posting rides and accepting bookings.`,
              data: { balance, minBalance },
            },
          });
        }
      }
    }

    // Notify passengers — prompt them to rate
    await Promise.all(
      bookings.map((b) =>
        this.prisma.notification.create({
          data: {
            userId: b.passengerId,
            type: 'trip_completed',
            title: 'Trip Completed!',
            body: `You have arrived at ${trip.destName}. How was your ride? Please rate your driver.`,
            data: { tripId, bookingId: b.id },
          },
        }),
      ),
    );

    // Calculate total earnings for this trip
    const earningsResult = await this.prisma.booking.aggregate({
      where: { rideId: tripId, status: 'completed' },
      _sum: { totalAmount: true },
    });

    return {
      message: 'Trip completed successfully',
      tripId,
      status: 'completed',
      totalPassengers: bookings.length,
      totalEarnings: earningsResult._sum.totalAmount ?? 0,
    };
  }
async getDriverLocation(tripId: string) {
    const trip = await this.prisma.ride.findUnique({
      where: { id: tripId },
      include: {
        driver: true,
      },
    });

    if (!trip) {
      throw new NotFoundException('Trip not found');
    }

    return {
      success: true,
      data: {
        lat: trip.driver?.lastLat ?? null,
        lng: trip.driver?.lastLng ?? null,
        lastUpdatedAt: trip.driver?.lastLocationAt ?? null,
        tripStatus: trip.status,
      },
    };
  }
}