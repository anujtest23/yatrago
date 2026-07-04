import { Module } from '@nestjs/common';
import { WalletController } from './wallet.controller';

// WalletService itself lives in the global PlatformModule; this module
// only exposes the HTTP surface for a user's own wallet.
@Module({
  controllers: [WalletController],
})
export class WalletModule {}
