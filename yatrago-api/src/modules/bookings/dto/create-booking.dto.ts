import { IsString, IsInt, IsOptional, IsEnum, Min, Max } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

enum PaymentMethod {
  cash = 'cash',
  esewa = 'esewa',
  khalti = 'khalti',
}

export class CreateBookingDto {
  @ApiProperty({ example: 'trip-uuid-here' })
  @IsString()
  rideId: string;

  @ApiProperty({ example: 1 })
  @IsInt()
  @Min(1)
  @Max(10)
  seatsBooked: number;

  @ApiProperty({ enum: PaymentMethod, example: 'khalti' })
  @IsEnum(PaymentMethod)
  paymentMethod: PaymentMethod;

  @ApiPropertyOptional({ example: 'YATRAGO10' })
  @IsOptional()
  @IsString()
  couponCode?: string;
}