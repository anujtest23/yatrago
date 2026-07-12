import { Controller, Get, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { WalletService } from '../platform/wallet.service';

// Wallet top-ups are now self-service via the online payment gateway; see
// PaymentsController (/wallet/payments/*). Admins no longer approve top-ups.
@ApiTags('Wallet')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('wallet')
export class WalletController {
  constructor(private walletService: WalletService) {}

  @Get()
  @ApiOperation({ summary: 'Get wallet balance and recent transactions' })
  getWallet(@CurrentUser() user: any) {
    return this.walletService.getBalance(user.id);
  }

  @Get('commissions')
  @ApiOperation({ summary: 'Get driver commission deduction history' })
  getCommissions(@CurrentUser() user: any) {
    return this.walletService.getCommissions(user.id);
  }
}
