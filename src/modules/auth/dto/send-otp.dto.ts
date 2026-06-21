import { IsString, Matches } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class SendOtpDto {
  @ApiProperty({ example: '+9779800000000' })
  @IsString()
  @Matches(/^\+977[0-9]{10}$/, {
    message: 'Phone number must be a valid Nepal number starting with +977',
  })
  phoneNumber: string;
}