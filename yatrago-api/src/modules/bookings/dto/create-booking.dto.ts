import {
  IsString,
  IsInt,
  IsOptional,
  IsNumber,
  Min,
  Max,
  MaxLength,
} from 'class-validator';
import { Type } from 'class-transformer';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class CreateBookingDto {
  @ApiProperty({ example: 'trip-uuid-here' })
  @IsString()
  rideId: string;

  @ApiProperty({ example: 1 })
  @IsInt()
  @Min(1)
  @Max(10)
  seatsBooked: number;

  // Passenger pickup point (defaults to the searched origin). Shown to the
  // driver as a map marker with route-deviation figures.
  @ApiPropertyOptional({ example: 27.7172 })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  pickupLat?: number;

  @ApiPropertyOptional({ example: 85.324 })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  pickupLng?: number;

  @ApiPropertyOptional({ example: 'Gaushala, Kathmandu' })
  @IsOptional()
  @IsString()
  @MaxLength(200)
  pickupName?: string;

  @ApiPropertyOptional({ example: 28.2096 })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  dropLat?: number;

  @ApiPropertyOptional({ example: 83.9856 })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  dropLng?: number;

  @ApiPropertyOptional({ example: 'Lakeside, Pokhara' })
  @IsOptional()
  @IsString()
  @MaxLength(200)
  dropName?: string;

  @ApiPropertyOptional({ example: 'YATRAGO10' })
  @IsOptional()
  @IsString()
  couponCode?: string;
}
