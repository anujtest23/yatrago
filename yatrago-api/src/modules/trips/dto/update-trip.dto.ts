import {
  IsString,
  IsNumber,
  IsInt,
  IsEnum,
  IsOptional,
  IsBoolean,
  IsDateString,
  Min,
  Max,
  MaxLength,
} from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';

enum SmokingPref {
  no_smoking = 'no_smoking',
  smoking_ok = 'smoking_ok',
}

enum LuggagePref {
  no_luggage = 'no_luggage',
  small_only = 'small_only',
  any = 'any',
}

export class UpdateTripDto {
  @ApiPropertyOptional({ example: '2026-07-01T09:00:00.000Z' })
  @IsOptional()
  @IsDateString()
  departureAt?: string;

  @ApiPropertyOptional({ example: 2 })
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(50)
  totalSeats?: number;

  @ApiPropertyOptional({ example: 900 })
  @IsOptional()
  @IsNumber()
  @Min(0)
  pricePerSeat?: number;

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

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(500)
  notes?: string;
}