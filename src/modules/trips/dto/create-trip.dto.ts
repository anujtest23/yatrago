import {
  IsString,
  IsNumber,
  IsInt,
  IsEnum,
  IsOptional,
  IsBoolean,
  IsDateString,
  IsArray,
  ValidateNested,
  Min,
  Max,
  MaxLength,
} from 'class-validator';
import { Type } from 'class-transformer';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

enum SmokingPref {
  no_smoking = 'no_smoking',
  smoking_ok = 'smoking_ok',
}

enum LuggagePref {
  no_luggage = 'no_luggage',
  small_only = 'small_only',
  any = 'any',
}

export class RideStopDto {
  @ApiProperty({ example: 'Muglin' })
  @IsString()
  @MaxLength(200)
  locationName: string;

  @ApiProperty({ example: 27.8626 })
  @IsNumber()
  lat: number;

  @ApiProperty({ example: 84.7212 })
  @IsNumber()
  lng: number;

  @ApiProperty({ example: 1 })
  @IsInt()
  @Min(1)
  stopOrder: number;

  @ApiPropertyOptional({ example: 90 })
  @IsOptional()
  @IsInt()
  minutesFromStart?: number;
}

export class CreateTripDto {
  @ApiProperty({ example: 'vehicle-uuid-here' })
  @IsString()
  vehicleId: string;

  @ApiProperty({ example: 'Kathmandu' })
  @IsString()
  @MaxLength(200)
  originName: string;

  @ApiProperty({ example: 27.7172 })
  @IsNumber()
  originLat: number;

  @ApiProperty({ example: 85.324 })
  @IsNumber()
  originLng: number;

  @ApiProperty({ example: 'Pokhara' })
  @IsString()
  @MaxLength(200)
  destName: string;

  @ApiProperty({ example: 28.2096 })
  @IsNumber()
  destLat: number;

  @ApiProperty({ example: 83.9856 })
  @IsNumber()
  destLng: number;

  @ApiProperty({ example: '2026-07-01T08:00:00.000Z' })
  @IsDateString()
  departureAt: string;

  @ApiProperty({ example: 3 })
  @IsInt()
  @Min(1)
  @Max(50)
  totalSeats: number;

  @ApiProperty({ example: 800 })
  @IsNumber()
  @Min(0)
  pricePerSeat: number;

  @ApiPropertyOptional({ example: false })
  @IsOptional()
  @IsBoolean()
  womenOnly?: boolean;

  @ApiPropertyOptional({ enum: SmokingPref })
  @IsOptional()
  @IsEnum(SmokingPref)
  smokingPref?: SmokingPref;

  @ApiPropertyOptional({ enum: LuggagePref })
  @IsOptional()
  @IsEnum(LuggagePref)
  luggagePref?: LuggagePref;

  @ApiPropertyOptional({ example: 'AC car, comfortable ride' })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  notes?: string;

  @ApiPropertyOptional({ type: [RideStopDto] })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => RideStopDto)
  stops?: RideStopDto[];
}
