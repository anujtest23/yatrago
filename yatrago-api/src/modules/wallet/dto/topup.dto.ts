import { IsNumber, Min } from 'class-validator';
import { Type } from 'class-transformer';
import { ApiProperty } from '@nestjs/swagger';

export class TopUpDto {
  @ApiProperty({ example: 1000, description: 'Amount in NPR to add to wallet' })
  @Type(() => Number)
  @IsNumber()
  @Min(1)
  amount: number;
}
