import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../../database/prisma.service';
import { SearchTripsDto } from './search.dto';

const EARTH_RADIUS_KM = 6371;
const PROXIMITY_RADIUS_KM = 30;
// Hard ceiling on the pre-filter fetch for proximity search. The endpoint is
// unauthenticated, so an unbounded findMany is a resource-exhaustion vector
// (CWE-770). Ride volume per region is small; this bound is generous.
const PROXIMITY_FETCH_CAP: number = 500;

@Injectable()
export class SearchService {
  private readonly logger = new Logger(SearchService.name);

  constructor(private prisma: PrismaService) {}

  // ── Haversine distance between two lat/lng points, in km ──────
  private haversineDistanceKm(
    lat1: number,
    lng1: number,
    lat2: number,
    lng2: number,
  ): number {
    const toRad = (deg: number) => (deg * Math.PI) / 180;
    const dLat = toRad(lat2 - lat1);
    const dLng = toRad(lng2 - lng1);
    const a =
      Math.sin(dLat / 2) ** 2 +
      Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return EARTH_RADIUS_KM * c;
  }

  async searchTrips(dto: SearchTripsDto) {
    const page = dto.page ?? 1;
    const limit = dto.limit ?? 10;
    const skip = (page - 1) * limit;
    const seats = dto.seats ?? 1;

    // Build date range only if a date is provided
    let startOfDay: Date | undefined;
    let endOfDay: Date | undefined;

    if (dto.date) {
      const searchDate = new Date(dto.date);

      startOfDay = new Date(searchDate);
      startOfDay.setHours(0, 0, 0, 0);

      endOfDay = new Date(searchDate);
      endOfDay.setHours(23, 59, 59, 999);
    }

    // Build sort order
    let orderBy: any = { departureAt: 'asc' };

    if (dto.sortBy === 'price_asc') {
      orderBy = { pricePerSeat: 'asc' };
    }

    if (dto.sortBy === 'price_desc') {
      orderBy = { pricePerSeat: 'desc' };
    }

    if (dto.sortBy === 'departure_desc') {
      orderBy = { departureAt: 'desc' };
    }

    if (dto.sortBy === 'rating') {
      orderBy = { driver: { averageRating: 'desc' } };
    }

    // Build filters
    const where = {
      status: 'published' as const,

      availableSeats: {
        gte: seats,
      },

      ...(dto.date && {
        departureAt: {
          gte: startOfDay!,
          lte: endOfDay!,
        },
      }),

      ...(dto.origin &&
        dto.origin.trim() !== '' && {
          originName: {
            contains: dto.origin,
            mode: 'insensitive' as const,
          },
        }),

      ...(dto.destination &&
        dto.destination.trim() !== '' && {
          destName: {
            contains: dto.destination,
            mode: 'insensitive' as const,
          },
        }),

      ...(dto.womenOnly === true && {
        womenOnly: true,
      }),
    };

    // Proximity filtering (destLat/destLng and/or originLat/originLng) is done
    // post-fetch in JS rather than via a raw SQL Haversine query. Ride volume
    // per country/region is small (thousands, not millions) so there's no
    // need for a DB-level geo query — and it keeps this in line with the rest
    // of the codebase, which uses the Prisma query builder exclusively.
    const hasProximityFilter =
      (dto.destLat !== undefined && dto.destLng !== undefined) ||
      (dto.originLat !== undefined && dto.originLng !== undefined);

    // When filtering by proximity we can't paginate at the DB level (the
    // distance check happens in JS afterwards), so fetch the full matching
    // set and paginate manually below.
    const [total, allRides] = await Promise.all([
      hasProximityFilter
        ? Promise.resolve(0)
        : this.prisma.ride.count({ where }),
      this.prisma.ride.findMany({
        where,
        ...(hasProximityFilter
          ? { take: PROXIMITY_FETCH_CAP }
          : { skip, take: limit }),
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
            orderBy: {
              stopOrder: 'asc',
            },
            select: {
              locationName: true,
              lat: true,
              lng: true,
              stopOrder: true,
              minutesFromStart: true,
            },
          },
          _count: {
            select: {
              bookings: true,
            },
          },
        },
      }),
    ]);

    // Two-tier matching: Tier 1 (nearby, <=30km both ends) always ranks above
    // Tier 2 (same origin/dest city, but outside the 30km radius) — this lets
    // passengers in large cities (Kathmandu/Pokhara) still discover rides
    // that travel between the same cities even if the exact pickup/drop
    // points are farther apart than the proximity radius.
    let rides: typeof allRides;
    let finalTotal = total;
    const matchTypeById = new Map<string, 'nearby' | 'city'>();

    if (hasProximityFilter && allRides.length === PROXIMITY_FETCH_CAP) {
      // Coverage was bounded — surface it rather than silently dropping rides.
      this.logger.warn(
        `Proximity search hit the ${PROXIMITY_FETCH_CAP}-row fetch cap; some matches may be omitted.`,
      );
    }

    if (hasProximityFilter) {
      const originDist = (ride: (typeof allRides)[number]) =>
        dto.originLat === undefined || dto.originLng === undefined
          ? 0
          : this.haversineDistanceKm(
              dto.originLat,
              dto.originLng,
              ride.originLat,
              ride.originLng,
            );

      const destDist = (ride: (typeof allRides)[number]) =>
        dto.destLat === undefined || dto.destLng === undefined
          ? 0
          : this.haversineDistanceKm(
              dto.destLat,
              dto.destLng,
              ride.destLat,
              ride.destLng,
            );

      const tier1 = allRides.filter((ride) => {
        const originOk =
          dto.originLat === undefined ||
          dto.originLng === undefined ||
          originDist(ride) <= PROXIMITY_RADIUS_KM;
        const destOk =
          dto.destLat === undefined ||
          dto.destLng === undefined ||
          destDist(ride) <= PROXIMITY_RADIUS_KM;
        return originOk && destOk;
      });

      const tier1Ids = new Set(tier1.map((r) => r.id));

      const tier2 =
        dto.originCity && dto.destCity
          ? allRides.filter(
              (ride) =>
                !tier1Ids.has(ride.id) &&
                ride.originCity?.toLowerCase() ===
                  dto.originCity!.toLowerCase() &&
                ride.destCity?.toLowerCase() === dto.destCity!.toLowerCase(),
            )
          : [];

      tier1.sort(
        (a, b) => originDist(a) + destDist(a) - (originDist(b) + destDist(b)),
      );

      for (const ride of tier1) matchTypeById.set(ride.id, 'nearby');
      for (const ride of tier2) matchTypeById.set(ride.id, 'city');

      rides = [...tier1, ...tier2];
      finalTotal = rides.length;
      rides = rides.slice(skip, skip + limit);
    } else {
      rides = allRides;
    }

    // Shape response
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
      matchType: matchTypeById.get(ride.id) ?? 'nearby',
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
        total: finalTotal,
        page,
        limit,
        totalPages: Math.ceil(finalTotal / limit),
        hasNextPage: page * limit < finalTotal,
        hasPrevPage: page > 1,
      },
    };
  }
}
