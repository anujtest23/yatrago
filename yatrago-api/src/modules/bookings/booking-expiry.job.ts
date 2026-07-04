import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { PrismaService } from '../../database/prisma.service';
import { AppConfigService } from '../platform/app-config.service';
import { NotificationsService } from '../notifications/notifications.service';

// Expires stale pending booking requests the driver never responded to,
// after the admin-configured window. Pending requests do not reserve seats
// (seats are held only once a driver accepts), so nothing needs restoring.
@Injectable()
export class BookingExpiryJob {
  private readonly logger = new Logger(BookingExpiryJob.name);

  constructor(
    private prisma: PrismaService,
    private appConfig: AppConfigService,
    private notifications: NotificationsService,
  ) {}

  @Cron(CronExpression.EVERY_MINUTE)
  async expireStaleBookings() {
    const expiryMinutes = await this.appConfig.get('booking_expiry_minutes');
    const cutoff = new Date(Date.now() - expiryMinutes * 60_000);

    const stale = await this.prisma.booking.findMany({
      where: {
        status: 'pending',
        bookedAt: { lt: cutoff },
      },
      take: 100,
    });

    for (const booking of stale) {
      try {
        // Guard: only expire if still pending (driver may have just accepted)
        const updated = await this.prisma.booking.updateMany({
          where: { id: booking.id, status: 'pending' },
          data: {
            status: 'expired',
            cancellationReason: `Expired after ${expiryMinutes} minutes without a driver response`,
            cancelledAt: new Date(),
          },
        });
        if (updated.count === 0) continue;

        await this.notifications.createNotification(
          booking.passengerId,
          'booking_expired',
          'Booking Expired',
          'Your booking request expired because the driver did not respond in time. You can request another ride.',
          { bookingId: booking.id },
        );
      } catch (error) {
        this.logger.error(
          `Failed to expire booking ${booking.id}: ${error.message}`,
        );
      }
    }

    if (stale.length > 0) {
      this.logger.log(`Expired ${stale.length} stale booking(s)`);
    }
  }
}
