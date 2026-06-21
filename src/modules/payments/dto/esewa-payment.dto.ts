import { IsString, IsNumber, Min } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class EsewaInitiateDto {
  @ApiProperty({ example: 'booking-uuid-here' })
  @IsString()
  bookingId: string;

  @ApiProperty({ example: 850 })
  @IsNumber()
  @Min(1)
  amount: number;
}

export class EsewaVerifyDto {
  @ApiProperty({ example: 'encoded-response-from-esewa' })
  @IsString()
  encodedData: string;

  @ApiProperty({ example: 'booking-uuid-here' })
  @IsString()
  bookingId: string;
}