import { Module } from '@nestjs/common';
import { SafetyController } from './safety.controller';
import { EmergencyContactsController } from './emergency-contacts.controller';
import { SafetyService } from './safety.service';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [NotificationsModule],
  controllers: [SafetyController, EmergencyContactsController],
  providers: [SafetyService],
})
export class SafetyModule {}
