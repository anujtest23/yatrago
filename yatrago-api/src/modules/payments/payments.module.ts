import { Module } from '@nestjs/common';
import { PaymentsController } from './payments.controller';
import { KhaltiService } from './khalti/khalti.service';
import { EsewaService } from './esewa/esewa.service';

@Module({
  controllers: [PaymentsController],
  providers: [KhaltiService, EsewaService],
  exports: [KhaltiService, EsewaService],
})
export class PaymentsModule {}