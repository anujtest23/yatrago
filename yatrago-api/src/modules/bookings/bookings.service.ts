import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
  ConflictException,
} from '@nestjs/common';
import { PrismaService } from '../../database/prisma.service';
import { CreateBookingDto } from './dto/create-booking.dto';
import { CancelBookingDto } from './dto/cancel-booking.dto';
import { RejectBookingDto } from './dto/reject-booking.dto';
import { SendMessageDto } from './dto/send-message.dto';

import { NotificationsService } from '../notifications/notifications.service';
@Injectable()
export class BookingsService {
  constructor(
    private prisma: PrismaService,
    private notifications: NotificationsService,
  ) {}

  // ── POST /bookings ───────────────────────────────────────────
  async create(userId: string, dto: CreateBookingDto) {
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

    // Check enough seats
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

    // Calculate total amount
    const totalAmount = ride.pricePerSeat * dto.seatsBooked;

    // For cash payment — confirm immediately
    // For esewa/khalti — stay pending until payment verified
    const bookingStatus =
      dto.paymentMethod === 'cash' ? 'confirmed' : 'pending';
    const paymentStatus =
      dto.paymentMethod === 'cash' ? 'paid' : 'pending';

    // Create booking in a transaction
    const booking = await this.prisma.$transaction(async (tx) => {
      const newBooking = await tx.booking.create({
        data: {
          rideId: dto.rideId,
          passengerId: userId,
          seatsBooked: dto.seatsBooked,
          totalAmount,
          status: bookingStatus as any,
          paymentStatus: paymentStatus as any,
          couponCode: dto.couponCode,
          confirmedAt: bookingStatus === 'confirmed' ? new Date() : null,
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

      // Reduce available seats
      await tx.ride.update({
        where: { id: dto.rideId },
        data: {
          availableSeats: {
            decrement: dto.seatsBooked,
          },
        },
      });

      return newBooking;
    });

    return {
      message:
        dto.paymentMethod === 'cash'
          ? 'Booking confirmed. Pay cash to the driver.'
          : 'Booking created. Complete payment to confirm.',
      booking,
    };
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
        payments: true,
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

    return booking;
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

    // Cancel booking and restore seats in a transaction
    await this.prisma.$transaction(async (tx) => {
      await tx.booking.update({
        where: { id: bookingId },
        data: {
          status: 'cancelled' as any,
          cancellationReason: dto.reason ?? 'Cancelled by passenger',
          cancelledAt: new Date(),
        },
      });

      // Restore available seats on the ride
      await tx.ride.update({
        where: { id: booking.rideId },
        data: {
          availableSeats: {
            increment: booking.seatsBooked,
          },
        },
      });
    });

    return { message: 'Booking cancelled successfully' };
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

    const updated = await this.prisma.booking.update({
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
          },
        },
      },
    });
    // Notify passenger their booking was accepted
    await this.notifications.createNotification(
      booking.passengerId,
      'booking_confirmed',
      'Booking Confirmed!',
      `Your booking has been accepted by the driver.`,
      { bookingId },
    );

    return {
      message: 'Booking accepted successfully',
      booking: updated,
    };
  }

  // ── PATCH /bookings/:id/reject ───────────────────────────────
  async reject(
    userId: string,
    bookingId: string,
    dto: RejectBookingDto,
  ) {
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

    // Reject and restore seats
    await this.prisma.$transaction(async (tx) => {
      await tx.booking.update({
        where: { id: bookingId },
        data: {
          status: 'rejected' as any,
          cancellationReason: dto.reason ?? 'Rejected by driver',
          cancelledAt: new Date(),
        },
      });

      await tx.ride.update({
        where: { id: booking.rideId },
        data: {
          availableSeats: {
            increment: booking.seatsBooked,
          },
        },
      });
    });
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
  // ── POST /messages ───────────────────────────────────────────
  async sendMessage(userId: string, dto: SendMessageDto) {
    const booking = await this.prisma.booking.findUnique({
      where: { id: dto.bookingId },
      include: {
        ride: {
          include: { driver: true },
        },
      },
    });

    if (!booking) throw new NotFoundException('Booking not found');

    // Verify sender is part of this booking
    const driver = await this.prisma.driverProfile.findUnique({
      where: { userId },
    });

    const isPassenger = booking.passengerId === userId;
    const isDriver = driver && booking.ride.driverId === driver.id;

    if (!isPassenger && !isDriver) {
      throw new ForbiddenException('You are not part of this booking');
    }

    // Receiver is the other party
    const receiverId = isPassenger ? booking.ride.driver.userId : booking.passengerId;

    const message = await this.prisma.message.create({
      data: {
        bookingId: dto.bookingId,
        senderId: userId,
        receiverId,
        content: dto.content,
      },
      include: {
        sender: {
          select: {
            id: true,
            fullName: true,
            profilePhotoUrl: true,
          },
        },
      },
    });

    return { message: 'Message sent', data: message };
  }

  // ── GET /messages/:bookingId ─────────────────────────────────
  async getMessages(userId: string, bookingId: string) {
    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
      include: {
        ride: {
          include: { driver: true },
        },
      },
    });

    if (!booking) throw new NotFoundException('Booking not found');

    const driver = await this.prisma.driverProfile.findUnique({
      where: { userId },
    });

    const isPassenger = booking.passengerId === userId;
    const isDriver = driver && booking.ride.driverId === driver.id;

    if (!isPassenger && !isDriver) {
      throw new ForbiddenException('You are not part of this booking');
    }

    const messages = await this.prisma.message.findMany({
      where: { bookingId },
      orderBy: { sentAt: 'asc' },
      include: {
        sender: {
          select: {
            id: true,
            fullName: true,
            profilePhotoUrl: true,
          },
        },
      },
    });

    // Mark all received messages as read
    await this.prisma.message.updateMany({
      where: {
        bookingId,
        receiverId: userId,
        isRead: false,
      },
      data: { isRead: true },
    });

    return { messages, total: messages.length };
  }
}