import {
  IsString,
  IsOptional,
  IsInt,
  IsBoolean,
  Min,
  IsDateString,
} from 'class-validator';
import { Transform, Type } from 'class-transformer';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class SearchTripsDto {
  @ApiProperty({ example: 'Kathmandu' })
  @IsString()
  origin: string;

  @ApiProperty({ example: 'Pokhara' })
  @IsString()
  destination: string;

  @ApiProperty({ example: '2026-07-01' })
  @IsDateString()
  date: string;

  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  seats?: number;

  @ApiPropertyOptional({ example: false })
  @IsOptional()
  @Transform(({ value }) => value === 'true' || value === true)
  @IsBoolean()
  womenOnly?: boolean;

  @ApiPropertyOptional({ example: 'price_asc', enum: ['price_asc', 'price_desc', 'departure_asc', 'departure_desc'] })
  @IsOptional()
  @IsString()
  sortBy?: string;

  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page?: number;

  @ApiPropertyOptional({ example: 10 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  limit?: number;
}