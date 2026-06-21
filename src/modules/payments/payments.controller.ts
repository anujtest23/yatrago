import { Controller, Post, Body, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { KhaltiService } from './khalti/khalti.service';
import { EsewaService } from './esewa/esewa.service';
import { KhaltiInitiateDto, KhaltiVerifyDto } from './dto/khalti-payment.dto';
import { EsewaInitiateDto, EsewaVerifyDto } from './dto/esewa-payment.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

@ApiTags('Payments')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('payments')
export class PaymentsController {
  constructor(
    private khaltiService: KhaltiService,
    private esewaService: EsewaService,
  ) {}

  @Post('khalti/initiate')
  @ApiOperation({ summary: 'Initiate Khalti payment for a booking' })
  khaltiInitiate(
    @CurrentUser() user: any,
    @Body() dto: KhaltiInitiateDto,
  ) {
    return this.khaltiService.initiate(user.id, dto);
  }

  @Post('khalti/verify')
  @ApiOperation({ summary: 'Verify Khalti payment after user completes' })
  khaltiVerify(
    @CurrentUser() user: any,
    @Body() dto: KhaltiVerifyDto,
  ) {
    return this.khaltiService.verify(user.id, dto);
  }

  @Post('esewa/initiate')
  @ApiOperation({ summary: 'Initiate eSewa payment for a booking' })
  esewaInitiate(
    @CurrentUser() user: any,
    @Body() dto: EsewaInitiateDto,
  ) {
    return this.esewaService.initiate(user.id, dto);
  }

  @Post('esewa/verify')
  @ApiOperation({ summary: 'Verify eSewa payment callback' })
  esewaVerify(
    @CurrentUser() user: any,
    @Body() dto: EsewaVerifyDto,
  ) {
    return this.esewaService.verify(user.id, dto);
  }
}