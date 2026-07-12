import {
  IsBoolean,
  IsEnum,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  IsDate,
  Matches,
  Min,
  MaxLength,
} from 'class-validator';
import { Type } from 'class-transformer';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { CouponAudience, DiscountType } from '@prisma/client';

export class CreateCouponDto {
  @ApiProperty({ example: 'YATRAGO10' })
  @IsString()
  @Matches(/^[A-Za-z0-9_-]{3,32}$/, {
    message: 'Code must be 3-32 letters, digits, hyphen or underscore',
  })
  code: string;

  @ApiPropertyOptional({ example: '10% off your next ride' })
  @IsOptional()
  @IsString()
  @MaxLength(200)
  description?: string;

  @ApiProperty({ enum: DiscountType })
  @IsEnum(DiscountType)
  discountType: DiscountType;

  @ApiProperty({ example: 10 })
  @IsNumber()
  @Min(0)
  discountValue: number;

  @ApiPropertyOptional({ example: 100, description: 'Cap for percentage coupons' })
  @IsOptional()
  @IsNumber()
  @Min(0)
  maxDiscount?: number;

  @ApiPropertyOptional({ example: 200 })
  @IsOptional()
  @IsNumber()
  @Min(0)
  minAmount?: number;

  @ApiPropertyOptional({ enum: CouponAudience, default: 'all' })
  @IsOptional()
  @IsEnum(CouponAudience)
  audience?: CouponAudience;

  @ApiPropertyOptional({ example: 1000, description: 'Global redemption cap' })
  @IsOptional()
  @IsInt()
  @Min(1)
  usageLimit?: number;

  @ApiPropertyOptional({ example: 1, description: 'Per-user redemption cap' })
  @IsOptional()
  @IsInt()
  @Min(1)
  perUserLimit?: number;

  @ApiPropertyOptional({ default: true })
  @IsOptional()
  @IsBoolean()
  isActive?: boolean;

  @ApiPropertyOptional({ example: '2026-07-01T00:00:00.000Z' })
  @IsOptional()
  @Type(() => Date)
  @IsDate()
  validFrom?: Date;

  @ApiPropertyOptional({ example: '2026-12-31T23:59:59.000Z' })
  @IsOptional()
  @Type(() => Date)
  @IsDate()
  validUntil?: Date;
}
