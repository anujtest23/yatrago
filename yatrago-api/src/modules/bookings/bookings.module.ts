import { Module } from '@nestjs/common';
import { BookingsController } from './bookings.controller';
import { BookingsService } from './bookings.service';
import { BookingExpiryJob } from './booking-expiry.job';
import { NotificationsModule } from '../notifications/notifications.module';
import { ChatModule } from '../chat/chat.module';
import { CouponsModule } from '../coupons/coupons.module';

@Module({
  imports: [NotificationsModule, ChatModule, CouponsModule],
  controllers: [BookingsController],
  providers: [BookingsService, BookingExpiryJob],
  exports: [BookingsService],
})
export class BookingsModule {}
