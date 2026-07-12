import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
  ConflictException,
} from '@nestjs/common';
import { PrismaService } from '../../database/prisma.service';
import { AppConfigService } from '../platform/app-config.service';
import { WalletService } from '../platform/wallet.service';
import { SmsService } from '../platform/sms.service';
import { CreateBookingDto } from './dto/create-booking.dto';
import { CancelBookingDto } from './dto/cancel-booking.dto';
import { RejectBookingDto } from './dto/reject-booking.dto';

import { NotificationsService } from '../notifications/notifications.service';
import { renderTemplate } from '../notifications/notification-templates';
import { mergeNotificationSettings } from '../notifications/notification-preferences';
import { FraudService } from '../platform/fraud.service';
import { ChatService } from '../chat/chat.service';
import { CouponsService } from '../coupons/coupons.service';
@Injectable()
export class BookingsService {
  constructor(
    private prisma: PrismaService,
    private notifications: NotificationsService,
    private appConfig: AppConfigService,
    private wallet: WalletService,
    private sms: SmsService,
    private fraud: FraudService,
    private chat: ChatService,
    private coupons: CouponsService,
  ) {}

  // ── POST /bookings ───────────────────────────────────────────
  async create(userId: string, dto: CreateBookingDto, idempotencyKey?: string) {
    // Idempotent replay: same key returns the original response
    if (idempotencyKey) {
      const existing = await this.prisma.idempotencyKey.findUnique({
        where: { key: idempotencyKey },
      });
      if (existing) {
        if (existing.userId !== userId) {
          throw new ForbiddenException(
            'Idempotency key belongs to another user',
          );
        }
        return existing.response as any;
      }
    }

    // Anti-automation: a human books a handful of rides an hour, a bot
    // books hundreds (inventory-lockup / harassment vector). Applies before
    // any seat math so spam never touches ride state.
    const recentBookings = await this.prisma.booking.count({
      where: {
        passengerId: userId,
        bookedAt: { gte: new Date(Date.now() - 3600_000) },
      },
    });
    if (recentBookings >= 8) {
      await this.fraud.record(userId, 'booking_spam', 10, {
        bookingsLastHour: recentBookings,
      });
      throw new BadRequestException(
        'Too many booking requests. Please try again later.',
      );
    }

    // Get the ride
    const ride = await this.prisma.ride.findUnique({
      where: { id: dto.rideId },
      include: {
        driver: {
          include: { user: true },
        },
      },
    });

    if (!ride) throw new NotFoundException('Ride not found');

    if (ride.status !== 'published') {
      throw new BadRequestException('This ride is no longer available');
    }

    // Passenger cannot book their own ride
    if (ride.driver.userId === userId) {
      throw new ForbiddenException('You cannot book your own ride');
    }

    // Check departure is still in the future
    if (ride.departureAt <= new Date()) {
      throw new BadRequestException('This ride has already departed');
    }

    // Early seat check for a friendly error; the authoritative check is
    // the conditional decrement inside the transaction below.
    if (ride.availableSeats < dto.seatsBooked) {
      throw new BadRequestException(
        `Only ${ride.availableSeats} seat(s) available`,
      );
    }

    // Check not already booked
    const existingBooking = await this.prisma.booking.findFirst({
      where: {
        rideId: dto.rideId,
        passengerId: userId,
        status: { in: ['pending', 'confirmed'] },
      },
    });

    if (existingBooking) {
      throw new ConflictException('You have already booked this ride');
    }

    // Women only check
    if (ride.womenOnly) {
      const user = await this.prisma.user.findUnique({
        where: { id: userId },
      });
      if (user?.gender !== 'female') {
        throw new ForbiddenException('This ride is for women only');
      }
    }

    // Calculate total amount (fare the passenger pays the driver directly)
    const grossAmount = ride.pricePerSeat * dto.seatsBooked;

    // Coupon: the discount is computed server-side from the stored coupon
    // definition — the client's couponCode is the only trusted input.
    let discountAmount = 0;
    let totalAmount = grossAmount;
    let couponQuote: { couponId: string; discountAmount: number } | null = null;
    if (dto.couponCode) {
      const quote = await this.coupons.quote(
        userId,
        dto.couponCode,
        grossAmount,
        'passenger',
      );
      discountAmount = quote.discountAmount;
      totalAmount = quote.finalAmount;
      couponQuote = { couponId: quote.couponId, discountAmount };
    }

    // Every booking starts as a request — the driver must accept it.
    // Seats are NOT reserved here; they decrement only on accept.
    let booking: any;
    try {
      booking = await this.prisma.booking.create({
        data: {
          rideId: dto.rideId,
          passengerId: userId,
          seatsBooked: dto.seatsBooked,
          totalAmount,
          status: 'pending',
          pickupLat: dto.pickupLat,
          pickupLng: dto.pickupLng,
          pickupName: dto.pickupName,
          dropLat: dto.dropLat,
          dropLng: dto.dropLng,
          dropName: dto.dropName,
          couponCode: dto.couponCode,
          discountAmount,
        },
        include: {
          ride: {
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
                  color: true,
                },
              },
              stops: { orderBy: { stopOrder: 'asc' } },
            },
          },
        },
      });
    } catch (error) {
      // The (rideId, passengerId) unique constraint can trip when a prior
      // booking for this ride exists in a terminal state. Return a clean 409
      // rather than letting a raw Prisma P2002 surface as a 500.
      if ((error as { code?: string }).code === 'P2002') {
        throw new ConflictException(
          'You already have a booking for this ride.',
        );
      }
      throw error;
    }

    // Ledger the coupon redemption now that the booking exists. Reversed if
    // the booking is later cancelled/rejected/expired.
    if (couponQuote) {
      await this.coupons.recordRedemption(this.prisma, {
        couponId: couponQuote.couponId,
        userId,
        bookingId: booking.id,
        discountAmount: couponQuote.discountAmount,
      });
    }

    // Notify the driver of the new booking request
    await this.notifications.createNotification(
      ride.driver.userId,
      'booking_requested',
      'New Booking Request',
      `You have a new booking request for your ride from ${ride.originName} to ${ride.destName}. Review and accept or reject it.`,
      { bookingId: booking.id, rideId: ride.id },
    );

    const response = {
      message: 'Booking request submitted. Waiting for the driver to accept.',
      booking,
    };

    // Persist idempotency record so a retried request replays this response
    if (idempotencyKey) {
      await this.prisma.idempotencyKey
        .create({
          data: {
            key: idempotencyKey,
            userId,
            endpoint: 'POST /bookings',
            response: JSON.parse(JSON.stringify(response)),
          },
        })
        .catch(() => undefined); // concurrent duplicate key — response already stored
    }

    return response;
  }

  // ── GET /bookings ────────────────────────────────────────────
  async findAll(userId: string, role: 'passenger' | 'driver', status?: string) {
    // Passenger sees their own bookings
    if (role === 'passenger') {
      const bookings = await this.prisma.booking.findMany({
        where: {
          passengerId: userId,
          ...(status && { status: status as any }),
        },
        include: {
          ride: {
            include: {
              driver: {
                include: {
                  user: {
                    select: {
                      fullName: true,
                      profilePhotoUrl: true,
                      phoneNumber: true,
                    },
                  },
                },
              },
              vehicle: {
                select: {
                  make: true,
                  model: true,
                  color: true,
                  vehicleType: true,
                },
              },
              stops: { orderBy: { stopOrder: 'asc' } },
            },
          },
        },
        orderBy: { bookedAt: 'desc' },
      });

      return { bookings, total: bookings.length };
    }

    // Driver sees bookings for their rides
    const driver = await this.prisma.driverProfile.findUnique({
      where: { userId },
    });

    if (!driver) throw new ForbiddenException('Driver profile not found');

    const bookings = await this.prisma.booking.findMany({
      where: {
        ride: { driverId: driver.id },
        ...(status && { status: status as any }),
      },
      include: {
        passenger: {
          select: {
            id: true,
            fullName: true,
            profilePhotoUrl: true,
            phoneNumber: true,
          },
        },
        ride: {
          select: {
            id: true,
            originName: true,
            destName: true,
            departureAt: true,
            pricePerSeat: true,
          },
        },
      },
      orderBy: { bookedAt: 'desc' },
    });

    return { bookings, total: bookings.length };
  }

  // ── GET /bookings/:id ────────────────────────────────────────
  async findOne(userId: string, bookingId: string) {
    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
      include: {
        ride: {
          include: {
            driver: {
              include: {
                user: {
                  select: {
                    id: true,
                    fullName: true,
                    profilePhotoUrl: true,
                    phoneNumber: true,
                  },
                },
              },
            },
            vehicle: true,
            stops: { orderBy: { stopOrder: 'asc' } },
          },
        },
        passenger: {
          select: {
            id: true,
            fullName: true,
            profilePhotoUrl: true,
            phoneNumber: true,
          },
        },
      },
    });

    if (!booking) throw new NotFoundException('Booking not found');

    // Only the passenger or the driver can view this booking
    const driver = await this.prisma.driverProfile.findUnique({
      where: { userId },
    });

    const isPassenger = booking.passengerId === userId;
    const isDriver = driver && booking.ride.driverId === driver.id;

    if (!isPassenger && !isDriver) {
      throw new ForbiddenException('You do not have access to this booking');
    }

    // Aggregate the passenger's rating (as a ratee) so the driver can judge
    // the request. Hidden ratings are excluded from the average.
    const ratingAgg = await this.prisma.rating.aggregate({
      where: {
        rateeId: booking.passengerId,
        rateeType: 'passenger',
        isHidden: false,
      },
      _avg: { score: true },
      _count: { score: true },
    });

    return {
      ...booking,
      passengerRating: {
        average: ratingAgg._avg.score ?? 0,
        count: ratingAgg._count.score,
      },
    };
  }

  // ── PATCH /bookings/:id/cancel ───────────────────────────────
  async cancel(userId: string, bookingId: string, dto: CancelBookingDto) {
    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
      include: { ride: true },
    });

    if (!booking) throw new NotFoundException('Booking not found');
    if (booking.passengerId !== userId) {
      throw new ForbiddenException('You can only cancel your own bookings');
    }

    if (!['pending', 'confirmed'].includes(booking.status)) {
      throw new BadRequestException(
        `Cannot cancel a booking with status: ${booking.status}`,
      );
    }

    // Only a confirmed booking holds reserved seats; a pending request does not.
    const wasConfirmed = booking.status === 'confirmed';

    await this.prisma.$transaction(async (tx) => {
      await tx.booking.update({
        where: { id: bookingId },
        data: {
          status: 'cancelled' as any,
          cancellationReason: dto.reason ?? 'Cancelled by passenger',
          cancelledAt: new Date(),
        },
      });

      if (wasConfirmed) {
        await tx.ride.update({
          where: { id: booking.rideId },
          data: {
            availableSeats: { increment: booking.seatsBooked },
          },
        });
      }
    });

    // Release any coupon redemption so it no longer counts against limits.
    await this.coupons.reverseForBooking(bookingId);

    // Serial cancellers strand drivers and lock up seats for real riders.
    const cancelledToday = await this.prisma.booking.count({
      where: {
        passengerId: userId,
        status: 'cancelled',
        cancelledAt: { gte: new Date(Date.now() - 24 * 3600_000) },
      },
    });
    if (cancelledToday >= 5) {
      await this.fraud.record(userId, 'rapid_cancellations', 15, {
        cancelledLast24h: cancelledToday,
      });
    }

    return {
      message: 'Booking cancelled successfully',
    };
  }

  // ── PATCH /bookings/:id/accept ───────────────────────────────
  async accept(userId: string, bookingId: string) {
    const driver = await this.prisma.driverProfile.findUnique({
      where: { userId },
    });
    if (!driver) throw new ForbiddenException('Driver profile not found');

    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
      include: { ride: true },
    });

    if (!booking) throw new NotFoundException('Booking not found');

    if (booking.ride.driverId !== driver.id) {
      throw new ForbiddenException('This booking is not for your ride');
    }

    if (booking.status !== 'pending') {
      throw new BadRequestException(
        `Cannot accept a booking with status: ${booking.status}`,
      );
    }

    // Driver must hold the minimum wallet balance to accept requests.
    const minBalance = await this.appConfig.get('min_wallet_balance');
    await this.wallet.assertMinBalance(userId, minBalance);

    // Reserve seats now (only accepted bookings hold seats). Atomic
    // conditional decrement prevents overbooking across concurrent accepts.
    const updated = await this.prisma.$transaction(async (tx) => {
      const seatLock = await tx.ride.updateMany({
        where: {
          id: booking.rideId,
          availableSeats: { gte: booking.seatsBooked },
        },
        data: { availableSeats: { decrement: booking.seatsBooked } },
      });

      if (seatLock.count === 0) {
        throw new ConflictException(
          'Not enough seats remaining to accept this request.',
        );
      }

      return tx.booking.update({
        where: { id: bookingId },
        data: {
          status: 'confirmed' as any,
          confirmedAt: new Date(),
        },
        include: {
          passenger: {
            select: {
              fullName: true,
              phoneNumber: true,
              notificationSettings: true,
            },
          },
          ride: { select: { availableSeats: true } },
        },
      });
    });

    // Notify passenger their booking was accepted
    await this.notifications.createNotification(
      booking.passengerId,
      'booking_confirmed',
      'Booking Confirmed!',
      `Your booking has been accepted by the driver.`,
      { bookingId },
    );

    // Accepting the request opens the conversation — signal both parties so
    // their chat/Messages tab lights up immediately.
    this.chat.notifyChatOpened(bookingId, booking.passengerId, userId);

    // SMS fallback for this critical event (skipped if bookings muted)
    if (
      mergeNotificationSettings(updated.passenger.notificationSettings).bookings
    ) {
      const sms = renderTemplate('booking_accepted', {
        origin: booking.ride.originName,
        dest: booking.ride.destName,
      });
      this.sms
        .send(updated.passenger.phoneNumber, sms.body)
        .catch(() => undefined);
    }

    // Seats now full → auto-reject every remaining pending request.
    if (updated.ride.availableSeats <= 0) {
      await this.autoRejectRemaining(booking.rideId, bookingId);
    }

    return {
      message: 'Booking accepted successfully',
      booking: updated,
    };
  }

  // Reject all still-pending requests for a ride once its seats are full.
  private async autoRejectRemaining(rideId: string, exceptBookingId: string) {
    const stillPending = await this.prisma.booking.findMany({
      where: {
        rideId,
        status: 'pending',
        id: { not: exceptBookingId },
      },
      select: { id: true, passengerId: true },
    });

    if (stillPending.length === 0) return;

    await this.prisma.booking.updateMany({
      where: { id: { in: stillPending.map((b) => b.id) } },
      data: {
        status: 'rejected' as any,
        cancellationReason: 'Ride is now full',
        cancelledAt: new Date(),
      },
    });

    await Promise.all(
      stillPending.map((b) => this.coupons.reverseForBooking(b.id)),
    );

    await Promise.all(
      stillPending.map((b) =>
        this.notifications.createNotification(
          b.passengerId,
          'booking_rejected',
          'Booking Rejected',
          'The ride is now full. Your request could not be accepted. You can search for another ride.',
          { bookingId: b.id },
        ),
      ),
    );
  }

  // ── PATCH /bookings/:id/reject ───────────────────────────────
  async reject(userId: string, bookingId: string, dto: RejectBookingDto) {
    const driver = await this.prisma.driverProfile.findUnique({
      where: { userId },
    });
    if (!driver) throw new ForbiddenException('Driver profile not found');

    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
      include: { ride: true },
    });

    if (!booking) throw new NotFoundException('Booking not found');

    if (booking.ride.driverId !== driver.id) {
      throw new ForbiddenException('This booking is not for your ride');
    }

    if (booking.status !== 'pending') {
      throw new BadRequestException(
        `Cannot reject a booking with status: ${booking.status}`,
      );
    }

    // Pending requests never reserve a seat, so nothing to restore.
    // Passengers pay drivers directly (off-app), so there is no refund.
    await this.prisma.booking.update({
      where: { id: bookingId },
      data: {
        status: 'rejected' as any,
        cancellationReason: dto.reason ?? 'Rejected by driver',
        cancelledAt: new Date(),
      },
    });

    await this.coupons.reverseForBooking(bookingId);

    // Notify passenger their booking was rejected
    await this.notifications.createNotification(
      booking.passengerId,
      'booking_rejected',
      'Booking Rejected',
      `Your booking request was not accepted. You can search for another ride.`,
      { bookingId },
    );

    return { message: 'Booking rejected' };
  }
}
