import { IsOptional, IsString, MaxLength } from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';

export class RejectTopUpDto {
  @ApiPropertyOptional({ description: 'Reason shown to the requester' })
  @IsOptional()
  @IsString()
  @MaxLength(300)
  note?: string;
}
