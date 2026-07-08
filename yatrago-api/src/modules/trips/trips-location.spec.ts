import { NotFoundException } from '@nestjs/common';
import { TripsService } from './trips.service';

/**
 * Regression tests for F-1: GET /trips/:id/location object-level authorization.
 * Only the trip's driver or a passenger with a live booking may read a
 * driver's live coordinates — never an arbitrary authenticated user.
 */
describe('TripsService.getDriverLocation authorization', () => {
  const DRIVER_USER = 'driver-user-1';
  const PASSENGER_USER = 'passenger-user-1';
  const OUTSIDER_USER = 'outsider-user-1';
  const TRIP_ID = 'trip-1';

  function buildService(bookingForOutsider: { id: string } | null) {
    const prisma = {
      ride: {
        findUnique: jest.fn().mockResolvedValue({
          id: TRIP_ID,
          status: 'in_progress',
          driver: {
            userId: DRIVER_USER,
            lastLat: 27.7,
            lastLng: 85.3,
            lastLocationAt: new Date(),
          },
        }),
      },
      booking: {
        // Returns a booking only for a genuine confirmed passenger.
        findFirst: jest
          .fn()
          .mockImplementation(({ where }: any) =>
            Promise.resolve(
              where.passengerId === PASSENGER_USER
                ? { id: 'b1' }
                : bookingForOutsider,
            ),
          ),
      },
    };
    // Only prisma is exercised by getDriverLocation.
    return new TripsService(prisma as any, {} as any, {} as any, {} as any);
  }

  it('returns coordinates for the trip driver', async () => {
    const svc = buildService(null);
    const res = await svc.getDriverLocation(DRIVER_USER, TRIP_ID);
    expect(res.data.lat).toBe(27.7);
  });

  it('returns coordinates for a confirmed passenger', async () => {
    const svc = buildService(null);
    const res = await svc.getDriverLocation(PASSENGER_USER, TRIP_ID);
    expect(res.data.lng).toBe(85.3);
  });

  it('denies an unrelated authenticated user (404, no oracle)', async () => {
    const svc = buildService(null);
    await expect(
      svc.getDriverLocation(OUTSIDER_USER, TRIP_ID),
    ).rejects.toBeInstanceOf(NotFoundException);
  });
});
