import {
  IsString,
  IsInt,
  IsOptional,
  IsEnum,
  IsArray,
  ArrayMaxSize,
  Min,
  Max,
  MaxLength,
} from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

enum RateeType {
  driver = 'driver',
  passenger = 'passenger',
}

export class CreateReviewDto {
  @ApiProperty({ example: 'booking-uuid-here' })
  @IsString()
  bookingId: string;

  @ApiProperty({ example: 'user-uuid-of-person-being-rated' })
  @IsString()
  rateeId: string;

  @ApiProperty({ enum: RateeType, example: 'driver' })
  @IsEnum(RateeType)
  rateeType: RateeType;

  @ApiProperty({ example: 5 })
  @IsInt()
  @Min(1)
  @Max(5)
  score: number;

  @ApiPropertyOptional({ example: 'Very smooth ride, arrived on time!' })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  reviewText?: string;

  @ApiPropertyOptional({
    example: ['punctual', 'friendly'],
    description: 'Quick-select feedback tags (max 5, each max 30 chars)',
  })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(5)
  @IsString({ each: true })
  @MaxLength(30, { each: true })
  tags?: string[];
}