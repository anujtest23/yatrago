import { Body, Controller, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CouponsService } from './coupons.service';
import { ValidateCouponDto } from './dto/validate-coupon.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { PendingDeletionGuard } from '../auth/guards/pending-deletion.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

@ApiTags('Coupons')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('coupons')
export class CouponsController {
  constructor(private coupons: CouponsService) {}

  @Post('validate')
  @UseGuards(PendingDeletionGuard)
  @ApiOperation({
    summary: 'Preview a coupon against an amount (server-computed discount)',
  })
  validate(@CurrentUser() user: any, @Body() dto: ValidateCouponDto) {
    const role = user.activeMode === 'driver' ? 'driver' : 'passenger';
    return this.coupons.quote(user.id, dto.code, dto.amount, role);
  }
}
