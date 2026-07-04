import {
  IsString,
  IsOptional,
  IsInt,
  IsNumber,
  IsBoolean,
  Min,
  IsDateString,
} from 'class-validator';
import { Transform, Type } from 'class-transformer';
import { ApiPropertyOptional } from '@nestjs/swagger';

export class SearchTripsDto {
  @ApiPropertyOptional({ example: 'Kathmandu' })
  @IsOptional()
  @IsString()
  origin?: string;

  @ApiPropertyOptional({ example: 'Pokhara' })
  @IsOptional()
  @IsString()
  destination?: string;

  @ApiPropertyOptional({ example: '2026-07-01' })
  @IsOptional()
  @IsDateString()
  date?: string;

  @ApiPropertyOptional({ example: 27.7172, description: 'Origin latitude for proximity search' })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  originLat?: number;

  @ApiPropertyOptional({ example: 85.324, description: 'Origin longitude for proximity search' })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  originLng?: number;

  @ApiPropertyOptional({ example: 28.2096, description: 'Destination latitude for proximity search' })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  destLat?: number;

  @ApiPropertyOptional({ example: 83.9856, description: 'Destination longitude for proximity search' })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  destLng?: number;

  @ApiPropertyOptional({ example: 'Kathmandu', description: 'Origin city for same-city fallback matching' })
  @IsOptional()
  @IsString()
  originCity?: string;

  @ApiPropertyOptional({ example: 'Pokhara', description: 'Destination city for same-city fallback matching' })
  @IsOptional()
  @IsString()
  destCity?: string;

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

  @ApiPropertyOptional({ example: 'price_asc', enum: ['price_asc', 'price_desc', 'departure_asc', 'departure_desc', 'rating'] })
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