import {
  Body,
  Controller,
  Get,
  Ip,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { PendingDeletionGuard } from '../auth/guards/pending-deletion.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { PaymentsService } from './payments.service';
import { InitiateTopUpDto } from './dto/initiate-topup.dto';
import { VerifyTopUpDto } from './dto/verify-topup.dto';
import { TopupHistoryDto } from './dto/topup-history.dto';

/**
 * Self-service wallet top-up via online payment gateway (eSewa for now).
 * Every route is JWT-guarded; the acting user is taken from the token, never
 * from the request body, so a user can only ever affect their OWN wallet.
 */
@ApiTags('Payments')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('wallet')
export class PaymentsController {
  constructor(private payments: PaymentsService) {}

  @Get('payment-methods')
  @ApiOperation({ summary: 'List available wallet top-up payment methods' })
  getPaymentMethods() {
    return this.payments.getPaymentMethods();
  }

  @Post('payments/esewa/initiate')
  @UseGuards(PendingDeletionGuard)
  @ApiOperation({ summary: 'Create an eSewa top-up intent and signed form' })
  // Tighter than the global limit — initiating payments is sensitive.
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  initiateEsewa(
    @CurrentUser() user: any,
    @Body() dto: InitiateTopUpDto,
    @Ip() ip: string,
  ) {
    return this.payments.initiateEsewa(user.id, dto.amount, ip);
  }

  @Post('payments/esewa/verify')
  @ApiOperation({
    summary: 'Verify an eSewa top-up server-side and credit the wallet',
  })
  @Throttle({ default: { limit: 20, ttl: 60_000 } })
  verifyEsewa(@CurrentUser() user: any, @Body() dto: VerifyTopUpDto) {
    return this.payments.verifyEsewa(user.id, dto.paymentId);
  }

  @Post('payments/esewa/reconcile')
  @ApiOperation({
    summary:
      "Reconcile the caller's pending eSewa top-ups (app open / resume). " +
      'Server re-checks each with eSewa and credits any that settled while ' +
      'the app was closed. Idempotent — cannot double-credit.',
  })
  @Throttle({ default: { limit: 12, ttl: 60_000 } })
  reconcile(@CurrentUser() user: any) {
    return this.payments.reconcileUserPending(user.id);
  }

  @Get('topups')
  @ApiOperation({
    summary:
      'Top-up attempt history (all statuses), cursor-paginated. Separate from ' +
      'the wallet transaction ledger.',
  })
  getTopupHistory(@CurrentUser() user: any, @Query() dto: TopupHistoryDto) {
    return this.payments.getTopupHistory(user.id, dto.limit, dto.cursor);
  }
}
