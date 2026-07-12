import {
  Controller,
  Get,
  Post,
  Put,
  Patch,
  Body,
  Param,
  Query,
  Req,
  UseGuards,
  UseInterceptors,
  UploadedFile,
} from '@nestjs/common';

import {
  ApiTags,
  ApiOperation,
  ApiBearerAuth,
  ApiConsumes,
  ApiBody,
  ApiQuery,
  ApiParam,
} from '@nestjs/swagger';

import { FileInterceptor } from '@nestjs/platform-express';
import { DriversService } from './drivers.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { PendingDeletionGuard } from '../auth/guards/pending-deletion.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { imageMulterConfig } from '../../common/utils/multer.config';
import { FileSignatureInterceptor } from '../../common/interceptors/file-signature.interceptor';
import { UpdateLocationDto } from './dto/update-location.dto';
import { RequestPayoutDto } from './dto/request-payout.dto';

@ApiTags('Drivers')
@Controller('drivers')
export class DriversController {
  constructor(private driversService: DriversService) {}

  @Post('apply')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @ApiOperation({
    summary: 'Start driver application — creates driver profile',
  })
  apply(@CurrentUser() user: any) {
    return this.driversService.apply(user.id);
  }

  @Post('citizenship')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @ApiOperation({ summary: 'Upload citizenship front or back' })
  @ApiQuery({ name: 'side', enum: ['front', 'back'], required: true })
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      properties: { file: { type: 'string', format: 'binary' } },
    },
  })
  @UseInterceptors(
    FileInterceptor('file', imageMulterConfig),
    FileSignatureInterceptor,
  )
  uploadCitizenship(
    @CurrentUser() user: any,
    @Query('side') side: 'front' | 'back',
    @UploadedFile() file: Express.Multer.File,
  ) {
    return this.driversService.uploadCitizenship(user.id, side, file);
  }

  @Post('license')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @ApiOperation({ summary: 'Upload driving license front or back' })
  @ApiQuery({ name: 'side', enum: ['front', 'back'], required: true })
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        file: { type: 'string', format: 'binary' },
        expiryDate: {
          type: 'string',
          example: '2028-12-31',
          description: 'License expiry date (ISO date, optional)',
        },
      },
    },
  })
  @UseInterceptors(
    FileInterceptor('file', imageMulterConfig),
    FileSignatureInterceptor,
  )
  uploadLicense(
    @CurrentUser() user: any,
    @Query('side') side: 'front' | 'back',
    @UploadedFile() file: Express.Multer.File,
    @Body('expiryDate') expiryDate?: string,
  ) {
    return this.driversService.uploadLicense(user.id, side, file, expiryDate);
  }

  @Post('selfie')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @ApiOperation({ summary: 'Upload selfie for liveness verification' })
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      properties: { file: { type: 'string', format: 'binary' } },
    },
  })
  @UseInterceptors(
    FileInterceptor('file', imageMulterConfig),
    FileSignatureInterceptor,
  )
  uploadSelfie(
    @CurrentUser() user: any,
    @UploadedFile() file: Express.Multer.File,
  ) {
    return this.driversService.uploadSelfie(user.id, file);
  }
  @Get('dashboard')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @ApiOperation({
    summary: 'Driver dashboard — earnings, trips, pending requests',
  })
  getDashboard(@CurrentUser() user: any) {
    return this.driversService.getDashboard(user.id);
  }

  @Get('status')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @ApiOperation({
    summary: 'Get driver verification status and document checklist',
  })
  getStatus(@CurrentUser() user: any) {
    return this.driversService.getStatus(user.id);
  }

  // No auth guard — public profile, viewable by passengers before booking
  @Get(':userId/profile')
  @ApiOperation({
    summary: 'Get public driver profile — visible to passengers',
  })
  @ApiParam({ name: 'userId', description: 'User ID of the driver' })
  getPublicProfile(@Param('userId') userId: string) {
    return this.driversService.getPublicProfile(userId);
  }

  @Post('payouts')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard, PendingDeletionGuard)
  @ApiOperation({ summary: 'Request a payout from wallet balance' })
  requestPayout(@CurrentUser() user: any, @Body() dto: RequestPayoutDto) {
    return this.driversService.requestPayout(user.id, dto);
  }

  @Get('payouts')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @ApiOperation({ summary: 'List own payout requests, newest first' })
  getPayouts(@CurrentUser() user: any) {
    return this.driversService.getPayouts(user.id);
  }

  @Patch('payouts/:id/cancel')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @ApiOperation({
    summary: 'Cancel own pending payout; funds return to wallet',
  })
  @ApiParam({ name: 'id', description: 'Payout ID' })
  cancelPayout(@CurrentUser() user: any, @Param('id') id: string) {
    return this.driversService.cancelPayout(user.id, id);
  }

  @Put('location')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  async updateLocation(@Req() req, @Body() dto: UpdateLocationDto) {
    return this.driversService.updateLocation(
      req.user.id,
      dto.lat,
      dto.lng,
      dto.isMock ?? false,
    );
  }
}
