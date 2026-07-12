import { IsString, MaxLength, MinLength } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class RejectReactivationDto {
  @ApiProperty({ example: 'Identity could not be verified.' })
  @IsString()
  @MinLength(3)
  @MaxLength(500)
  reason: string;
}
