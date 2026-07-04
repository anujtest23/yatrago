import { IsEnum, IsString, MaxLength } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

enum DevicePlatform {
  android = 'android',
  ios = 'ios',
}

export class RegisterDeviceTokenDto {
  @ApiProperty({ example: 'fcm-device-token-string' })
  @IsString()
  @MaxLength(4096)
  fcmToken: string;

  @ApiProperty({ enum: DevicePlatform, example: 'android' })
  @IsEnum(DevicePlatform)
  platform: DevicePlatform;
}
