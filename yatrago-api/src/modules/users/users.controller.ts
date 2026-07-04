import {
  Controller,
  Get,
  Patch,
  Delete,
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
import { diskStorage } from 'multer';
import { extname } from 'path';

import { UsersService } from './users.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

import { UpdateUserDto } from './dto/update-user.dto';
import { SwitchModeDto } from './dto/switch-mode.dto';
import { RegisterDeviceTokenDto } from './dto/register-device-token.dto';
import { UpdateNotificationSettingsDto } from './dto/update-notification-settings.dto';

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
    FileInterceptor('file', {
      storage: diskStorage({
        destination: './uploads',
        filename: (req, file, cb) => {
          const uniqueSuffix =
            Date.now() + '-' + Math.round(Math.random() * 1e9);

          cb(null, uniqueSuffix + extname(file.originalname));
        },
      }),
      limits: {
        fileSize: 5 * 1024 * 1024,
      },
      fileFilter: (req, file, cb) => {
        if (!file.mimetype.match(/\/(jpg|jpeg|png|webp)$/)) {
          cb(new Error('Only image files are allowed'), false);
        } else {
          cb(null, true);
        }
      },
    }),
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

  @Delete('me')
  @ApiOperation({
    summary:
      'Request account deletion (soft delete with 30-day grace period)',
  })
  deleteMe(@CurrentUser() user: any) {
    return this.usersService.deleteMe(user.id);
  }
}