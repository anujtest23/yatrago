import { Module } from '@nestjs/common';
import { PaymentsController } from './payments.controller';
import { PaymentsService } from './payments.service';
import { EsewaService } from './esewa.service';
import { PaymentsReconciliationJob } from './payments-reconciliation.job';

// WalletService / AuditService / FraudService come from the global
// PlatformModule; PrismaService from the global DatabaseModule.
// ScheduleModule is bootstrapped globally in AppModule.
@Module({
  controllers: [PaymentsController],
  providers: [PaymentsService, EsewaService, PaymentsReconciliationJob],
})
export class PaymentsModule {}
