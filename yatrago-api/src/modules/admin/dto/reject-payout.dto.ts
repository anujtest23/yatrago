import { IsString, MaxLength } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class RejectPayoutDto {
  @ApiProperty({ example: 'Account reference could not be verified.' })
  @IsString()
  @MaxLength(500)
  reason: string;
}
