import { IsString, IsNumber, Min } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class KhaltiInitiateDto {
  @ApiProperty({ example: 'booking-uuid-here' })
  @IsString()
  bookingId: string;

  @ApiProperty({ example: 850 })
  @IsNumber()
  @Min(1)
  amount: number;
}

export class KhaltiVerifyDto {
  @ApiProperty({ example: 'pidx_from_khalti' })
  @IsString()
  pidx: string;

  @ApiProperty({ example: 'booking-uuid-here' })
  @IsString()
  bookingId: string;
}