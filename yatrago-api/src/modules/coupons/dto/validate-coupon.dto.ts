import { IsNumber, IsString, Min } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

// Preview a coupon against a prospective amount (e.g. a ride fare) before
// booking. The server returns the authoritative discount; the client only
// displays it.
export class ValidateCouponDto {
  @ApiProperty({ example: 'YATRAGO10' })
  @IsString()
  code: string;

  @ApiProperty({ example: 500, description: 'Amount the discount applies to' })
  @IsNumber()
  @Min(0)
  amount: number;
}
