import { Module } from '@nestjs/common';
import { AdminController } from './admin.controller';
import { AdminService } from './admin.service';
import { AdminGuard } from './guards/admin.guard';
import { SuperAdminGuard } from './guards/super-admin.guard';
import { NotificationsModule } from '../notifications/notifications.module';
import { CouponsModule } from '../coupons/coupons.module';
import { SupportModule } from '../support/support.module';

@Module({
  imports: [NotificationsModule, CouponsModule, SupportModule],
  controllers: [AdminController],
  providers: [AdminService, AdminGuard, SuperAdminGuard],
})
export class AdminModule {}
