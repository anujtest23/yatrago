import { IsString, MaxLength } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class RejectDriverDto {
  @ApiProperty({ example: 'Documents are not clear. Please resubmit.' })
  @IsString()
  @MaxLength(500)
  reason: string;
}
