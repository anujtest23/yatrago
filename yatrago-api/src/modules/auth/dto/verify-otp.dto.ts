import { IsString, Matches, Length } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class VerifyOtpDto {
  @ApiProperty({ example: '+9779800000000' })
  @IsString()
  @Matches(/^\+977[0-9]{10}$/, {
    message: 'Phone number must be a valid Nepal number starting with +977',
  })
  phoneNumber: string;

  @ApiProperty({ example: '123456' })
  @IsString()
  @Length(6, 6, { message: 'OTP must be exactly 6 digits' })
  otp: string;
}