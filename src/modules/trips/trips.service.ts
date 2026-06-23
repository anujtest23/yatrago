import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
} from '@nestjs/common';
import { PrismaService } from '../../database/prisma.service';
import { CreateTripDto } from './dto/create-trip.dto';
import { UpdateTripDto } from './dto/update-trip.dto';

@Injectable()
export class TripsService {
  constructor(private prisma: PrismaService) {}

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

    // Departure must be in the future
    const departureAt = new Date(dto.departureAt);
    if (departureAt <= new Date()) {
      throw new BadRequestException('Departure time must be in the future');
    }

    const trip = await this.prisma.ride.create({
      data: {
        driverId: driver.id,
        vehicleId: dto.vehicleId,
        originName: dto.originName,
        originLat: dto.originLat,
        originLng: dto.originLng,
        destName: dto.destName,
        destLat: dto.destLat,
        destLng: dto.destLng,
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

    // Cannot edit departure if it's less than 1 hour away
    if (dto.departureAt) {
      const newDeparture = new Date(dto.departureAt);
      if (newDeparture <= new Date()) {
        throw new BadRequestException('Departure time must be in the future');
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

    // Cancel the trip
    await this.prisma.ride.update({
      where: { id: tripId },
      data: { status: 'cancelled' },
    });

    // Notify all confirmed passengers — cancel their bookings
    await this.prisma.booking.updateMany({
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

    return { message: 'Trip cancelled successfully' };
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
}