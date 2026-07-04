import { IsNumber, Min } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class OverrideRidePriceDto {
  @ApiProperty({ example: 1200, description: 'New price per seat in NPR' })
  @IsNumber()
  @Min(1)
  pricePerSeat: number;
}
