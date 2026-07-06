import {
  IsNumber,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import { Type } from 'class-transformer';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class TopUpDto {
  @ApiProperty({
    example: 1000,
    description: 'Amount in NPR requested for wallet top-up',
  })
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(1)
  @Max(100_000)
  amount: number;

  @ApiPropertyOptional({
    description: 'Off-app payment reference (bank slip / transaction id)',
  })
  @IsOptional()
  @IsString()
  @MaxLength(120)
  reference?: string;
}
