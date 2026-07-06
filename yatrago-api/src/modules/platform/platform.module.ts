import { Global, Module } from '@nestjs/common';
import { AppConfigService } from './app-config.service';
import { AuditService } from './audit.service';
import { WalletService } from './wallet.service';
import { SmsService } from './sms.service';
import { FileSignerService } from './file-signer.service';
import { EncryptionService } from './encryption.service';
import { FraudService } from './fraud.service';
import { FilesController } from './files.controller';
import { MetricsController } from './metrics.controller';
import { DataRetentionJob } from './data-retention.job';
import { StorageService } from './storage.service';
import { GeoIpService } from './geoip.service';
import { TorExitService } from './tor-exit.service';
import { LoginAnomalyService } from './login-anomaly.service';
import { MetricsService } from './metrics.service';
import { SecurityAlertsService } from './security-alerts.service';
import { SafeBrowsingService } from './safe-browsing.service';

// Global so any module can inject business-policy config, audit
// logging, wallet operations, and SMS sending without importing
// this module explicitly.
@Global()
@Module({
  controllers: [FilesController, MetricsController],
  providers: [
    AppConfigService,
    AuditService,
    WalletService,
    SmsService,
    FileSignerService,
    EncryptionService,
    FraudService,
    DataRetentionJob,
    StorageService,
    GeoIpService,
    TorExitService,
    LoginAnomalyService,
    MetricsService,
    SecurityAlertsService,
    SafeBrowsingService,
  ],
  exports: [
    AppConfigService,
    AuditService,
    WalletService,
    SmsService,
    FileSignerService,
    EncryptionService,
    FraudService,
    StorageService,
    GeoIpService,
    TorExitService,
    LoginAnomalyService,
    MetricsService,
    SecurityAlertsService,
    SafeBrowsingService,
  ],
})
export class PlatformModule {}
