import {
  IsNumber,
  IsOptional,
  IsString,
  Min,
  Max,
  MaxLength,
} from 'class-validator';
import { Type } from 'class-transformer';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class CreditWalletDto {
  @ApiProperty({ example: 1000, description: 'Amount in NPR to credit' })
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(1)
  @Max(1_000_000)
  amount: number;

  @ApiPropertyOptional({ example: 'Manual top-up via bank transfer' })
  @IsOptional()
  @IsString()
  @MaxLength(200)
  note?: string;
}
