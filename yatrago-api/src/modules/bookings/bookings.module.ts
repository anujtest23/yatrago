import { Module } from '@nestjs/common';
import { BookingsController } from './bookings.controller';
import { BookingsService } from './bookings.service';
import { BookingExpiryJob } from './booking-expiry.job';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [NotificationsModule],
  controllers: [BookingsController],
  providers: [BookingsService, BookingExpiryJob],
  exports: [BookingsService],
})
export class BookingsModule {}