import {
  Controller,
  Get,
  Patch,
  Body,
  Post,
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
} from '@nestjs/swagger';
import { FileInterceptor } from '@nestjs/platform-express';

import { UsersService } from './users.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { publicImageMulterConfig } from '../../common/utils/multer.config';
import { FileSignatureInterceptor } from '../../common/interceptors/file-signature.interceptor';

import { UpdateUserDto } from './dto/update-user.dto';
import { SwitchModeDto } from './dto/switch-mode.dto';
import { RegisterDeviceTokenDto } from './dto/register-device-token.dto';
import { UpdateNotificationSettingsDto } from './dto/update-notification-settings.dto';
import { UpdateNotificationPreferencesDto } from './dto/update-notification-preferences.dto';
import { UpdatePrivacySettingsDto } from './dto/update-privacy-settings.dto';
import { ConfirmDeletionDto } from './dto/confirm-deletion.dto';

@ApiTags('Users')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get('me')
  @ApiOperation({ summary: 'Get current user profile' })
  getMe(@CurrentUser() user: any) {
    return this.usersService.getMe(user.id);
  }

  @Patch('me')
  @ApiOperation({
    summary: 'Update name, gender, date of birth, language',
  })
  updateMe(@CurrentUser() user: any, @Body() dto: UpdateUserDto) {
    return this.usersService.updateMe(user.id, dto);
  }

  @Post('profile-photo')
  @ApiOperation({ summary: 'Upload profile photo' })
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        file: {
          type: 'string',
          format: 'binary',
        },
      },
    },
  })
  @UseInterceptors(
    FileInterceptor('file', publicImageMulterConfig),
    FileSignatureInterceptor,
  )
  uploadPhoto(
    @CurrentUser() user: any,
    @UploadedFile() file: Express.Multer.File,
  ) {
    return this.usersService.updateProfilePhoto(user.id, file);
  }

  @Patch('me/mode')
  @ApiOperation({
    summary: 'Switch between passenger and driver mode',
  })
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        mode: {
          type: 'string',
          enum: ['passenger', 'driver'],
        },
      },
    },
  })
  switchMode(@CurrentUser() user: any, @Body() dto: SwitchModeDto) {
    return this.usersService.switchMode(user.id, dto.mode);
  }

  @Post('me/device-token')
  @ApiOperation({
    summary: 'Register or refresh an FCM device token for push notifications',
  })
  registerDeviceToken(
    @CurrentUser() user: any,
    @Body() dto: RegisterDeviceTokenDto,
  ) {
    return this.usersService.registerDeviceToken(user.id, dto);
  }

  @Get('me/notification-settings')
  @ApiOperation({
    summary: 'Get notification preferences (merged over defaults)',
  })
  getNotificationSettings(@CurrentUser() user: any) {
    return this.usersService.getNotificationSettings(user.id);
  }

  @Patch('me/notification-settings')
  @ApiOperation({
    summary: 'Update notification preferences (partial)',
  })
  updateNotificationSettings(
    @CurrentUser() user: any,
    @Body() dto: UpdateNotificationSettingsDto,
  ) {
    return this.usersService.updateNotificationSettings(user.id, dto);
  }

  @Get('me/notification-preferences')
  @ApiOperation({ summary: 'Get channel×category notification preferences' })
  getNotificationPreferences(@CurrentUser() user: any) {
    return this.usersService.getNotificationPreferences(user.id);
  }

  @Patch('me/notification-preferences')
  @ApiOperation({ summary: 'Update channel×category notification preferences' })
  updateNotificationPreferences(
    @CurrentUser() user: any,
    @Body() dto: UpdateNotificationPreferencesDto,
  ) {
    return this.usersService.updateNotificationPreferences(user.id, dto);
  }

  @Get('me/privacy-settings')
  @ApiOperation({ summary: 'Get privacy settings' })
  getPrivacySettings(@CurrentUser() user: any) {
    return this.usersService.getPrivacySettings(user.id);
  }

  @Patch('me/privacy-settings')
  @ApiOperation({ summary: 'Update privacy settings' })
  updatePrivacySettings(
    @CurrentUser() user: any,
    @Body() dto: UpdatePrivacySettingsDto,
  ) {
    return this.usersService.updatePrivacySettings(user.id, dto);
  }

  @Get('me/export')
  @ApiOperation({ summary: 'Export all personal data held about this account' })
  exportData(@CurrentUser() user: any) {
    return this.usersService.exportData(user.id);
  }

  @Post('me/deletion/request-otp')
  @ApiOperation({
    summary: 'Send an OTP to confirm account deletion',
  })
  requestDeletionOtp(@CurrentUser() user: any) {
    return this.usersService.requestDeletionOtp(user.id);
  }

  @Post('me/deletion/confirm')
  @ApiOperation({
    summary:
      'Confirm account deletion with OTP (enters 30-day grace period; login+browse allowed, actions blocked)',
  })
  confirmDeletion(@CurrentUser() user: any, @Body() dto: ConfirmDeletionDto) {
    return this.usersService.confirmDeletion(user.id, dto.otp);
  }

  @Post('me/deletion/cancel')
  @ApiOperation({
    summary: 'Cancel a pending account deletion and reactivate the account',
  })
  cancelDeletion(@CurrentUser() user: any) {
    return this.usersService.cancelDeletion(user.id);
  }
}
