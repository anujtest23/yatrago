import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../database/prisma.service';
import { SearchTripsDto } from './search.dto';

@Injectable()
export class SearchService {
  constructor(private prisma: PrismaService) {}

  async searchTrips(dto: SearchTripsDto) {
    const page = dto.page ?? 1;
    const limit = dto.limit ?? 10;
    const skip = (page - 1) * limit;
    const seats = dto.seats ?? 1;

    // Build date range — search the entire day given
    const searchDate = new Date(dto.date);
    const startOfDay = new Date(searchDate);
    startOfDay.setHours(0, 0, 0, 0);
    const endOfDay = new Date(searchDate);
    endOfDay.setHours(23, 59, 59, 999);

    // Build sort order
    let orderBy: any = { departureAt: 'asc' };
    if (dto.sortBy === 'price_asc') orderBy = { pricePerSeat: 'asc' };
    if (dto.sortBy === 'price_desc') orderBy = { pricePerSeat: 'desc' };
    if (dto.sortBy === 'departure_desc') orderBy = { departureAt: 'desc' };

    const where = {
      // Match origin — case insensitive contains
      originName: {
        contains: dto.origin,
        mode: 'insensitive' as any,
      },
      // Match destination — case insensitive contains
      destName: {
        contains: dto.destination,
        mode: 'insensitive' as any,
      },
      // Only published rides
      status: 'published' as any,
      // Only future rides on the given date
      departureAt: {
        gte: startOfDay,
        lte: endOfDay,
      },
      // Must have enough seats
      availableSeats: {
        gte: seats,
      },
      // Women only filter
      ...(dto.womenOnly === true && { womenOnly: true }),
    };

    // Run count and data queries in parallel
    const [total, rides] = await Promise.all([
      this.prisma.ride.count({ where }),
      this.prisma.ride.findMany({
        where,
        skip,
        take: limit,
        orderBy,
        include: {
          driver: {
            select: {
              id: true,
              user: {
                select: {
                  id: true,
                  fullName: true,
                  profilePhotoUrl: true,
                },
              },
              averageRating: true,
              totalTrips: true,
              verificationStatus: true,
            },
          },
          vehicle: {
            select: {
              make: true,
              model: true,
              color: true,
              vehicleType: true,
              totalSeats: true,
            },
          },
          stops: {
            orderBy: { stopOrder: 'asc' },
            select: {
              locationName: true,
              lat: true,
              lng: true,
              stopOrder: true,
              minutesFromStart: true,
            },
          },
          _count: {
            select: { bookings: true },
          },
        },
      }),
    ]);

    // Shape the response cleanly
    const formattedRides = rides.map((ride) => ({
      id: ride.id,
      originName: ride.originName,
      originLat: ride.originLat,
      originLng: ride.originLng,
      destName: ride.destName,
      destLat: ride.destLat,
      destLng: ride.destLng,
      departureAt: ride.departureAt,
      availableSeats: ride.availableSeats,
      totalSeats: ride.totalSeats,
      pricePerSeat: ride.pricePerSeat,
      womenOnly: ride.womenOnly,
      smokingPref: ride.smokingPref,
      luggagePref: ride.luggagePref,
      notes: ride.notes,
      stops: ride.stops,
      driver: {
        id: ride.driver.id,
        fullName: ride.driver.user.fullName,
        profilePhotoUrl: ride.driver.user.profilePhotoUrl,
        averageRating: ride.driver.averageRating,
        totalTrips: ride.driver.totalTrips,
      },
      vehicle: ride.vehicle,
    }));

    return {
      rides: formattedRides,
      pagination: {
        total,
        page,
        limit,
        totalPages: Math.ceil(total / limit),
        hasNextPage: page * limit < total,
        hasPrevPage: page > 1,
      },
    };
  }
}