import { Body, Controller, Get, Post, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { WalletService } from '../platform/wallet.service';
import { TopUpDto } from './dto/topup.dto';

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

  @Post('topup')
  @ApiOperation({
    summary: 'Request a wallet top-up (credited after admin verification)',
  })
  topUp(@CurrentUser() user: any, @Body() dto: TopUpDto) {
    return this.walletService.requestTopUp(user.id, dto.amount, dto.reference);
  }

  @Get('topup-requests')
  @ApiOperation({ summary: 'List my top-up requests and their status' })
  listTopUpRequests(@CurrentUser() user: any) {
    return this.walletService.listTopUpRequests(user.id);
  }

  @Get('commissions')
  @ApiOperation({ summary: 'Get driver commission deduction history' })
  getCommissions(@CurrentUser() user: any) {
    return this.walletService.getCommissions(user.id);
  }
}
