import { IsString, IsOptional, MaxLength } from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';

export class RejectBookingDto {
  @ApiPropertyOptional({ example: 'Car is full' })
  @IsOptional()
  @IsString()
  @MaxLength(300)
  reason?: string;
}
