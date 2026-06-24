import {
  Controller,
  Post,
  Get,
  Body,
  UseGuards,
  UseInterceptors,
  UploadedFile,
  Query,
  Param,
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
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { imageMulterConfig } from '../../common/utils/multer.config';

@ApiTags('Drivers')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('drivers')
export class DriversController {
  constructor(private driversService: DriversService) {}

  @Post('apply')
  @ApiOperation({ summary: 'Start driver application — creates driver profile' })
  apply(@CurrentUser() user: any) {
    return this.driversService.apply(user.id);
  }

  @Post('citizenship')
  @ApiOperation({ summary: 'Upload citizenship front or back' })
  @ApiQuery({ name: 'side', enum: ['front', 'back'], required: true })
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      properties: { file: { type: 'string', format: 'binary' } },
    },
  })
  @UseInterceptors(FileInterceptor('file', imageMulterConfig))
  uploadCitizenship(
    @CurrentUser() user: any,
    @Query('side') side: 'front' | 'back',
    @UploadedFile() file: Express.Multer.File,
  ) {
    return this.driversService.uploadCitizenship(user.id, side, file);
  }

  @Post('license')
  @ApiOperation({ summary: 'Upload driving license front or back' })
  @ApiQuery({ name: 'side', enum: ['front', 'back'], required: true })
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      properties: { file: { type: 'string', format: 'binary' } },
    },
  })
  @UseInterceptors(FileInterceptor('file', imageMulterConfig))
  uploadLicense(
    @CurrentUser() user: any,
    @Query('side') side: 'front' | 'back',
    @UploadedFile() file: Express.Multer.File,
  ) {
    return this.driversService.uploadLicense(user.id, side, file);
  }

  @Post('selfie')
  @ApiOperation({ summary: 'Upload selfie for liveness verification' })
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      properties: { file: { type: 'string', format: 'binary' } },
    },
  })
  @UseInterceptors(FileInterceptor('file', imageMulterConfig))
  uploadSelfie(
    @CurrentUser() user: any,
    @UploadedFile() file: Express.Multer.File,
  ) {
    return this.driversService.uploadSelfie(user.id, file);
  }
@Get('dashboard')
  @ApiOperation({ summary: 'Driver dashboard — earnings, trips, pending requests' })
  getDashboard(@CurrentUser() user: any) {
    return this.driversService.getDashboard(user.id);
  }

  @Get('status')
  @ApiOperation({ summary: 'Get driver verification status and document checklist' })
  getStatus(@CurrentUser() user: any) {
    return this.driversService.getStatus(user.id);
  }
  @Get(':userId/profile')
  @ApiOperation({ summary: 'Get public driver profile — visible to passengers' })
  @ApiParam({ name: 'userId', description: 'User ID of the driver' })
  getPublicProfile(@Param('userId') userId: string) {
    return this.driversService.getPublicProfile(userId);
  }
}