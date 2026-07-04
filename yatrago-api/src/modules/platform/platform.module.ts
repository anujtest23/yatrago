import { Global, Module } from '@nestjs/common';
import { AppConfigService } from './app-config.service';
import { AuditService } from './audit.service';
import { WalletService } from './wallet.service';
import { SmsService } from './sms.service';

// Global so any module can inject business-policy config, audit
// logging, wallet operations, and SMS sending without importing
// this module explicitly.
@Global()
@Module({
  providers: [AppConfigService, AuditService, WalletService, SmsService],
  exports: [AppConfigService, AuditService, WalletService, SmsService],
})
export class PlatformModule {}
