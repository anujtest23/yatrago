import { IsString, Matches } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';
import { NEPAL_MOBILE_MESSAGE, NEPAL_MOBILE_REGEX } from './phone.constants';

export class SendOtpDto {
  @ApiProperty({ example: '+9779800000000' })
  @IsString()
  @Matches(NEPAL_MOBILE_REGEX, { message: NEPAL_MOBILE_MESSAGE })
  phoneNumber: string;
}
