import { IsOptional, IsString } from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';

export class ApplyDriverDto {
  @ApiPropertyOptional({ example: 'I want to earn extra income' })
  @IsOptional()
  @IsString()
  reason?: string;
}
