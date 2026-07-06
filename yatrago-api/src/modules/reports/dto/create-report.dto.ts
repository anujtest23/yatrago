import { IsOptional, IsString, IsUUID, MaxLength } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class CreateReportDto {
  @ApiProperty({
    example: 'user-uuid-here',
    description: 'User being reported',
  })
  @IsUUID()
  reportedId: string;

  @ApiPropertyOptional({ example: 'booking-uuid-here' })
  @IsOptional()
  @IsUUID()
  bookingId?: string;

  @ApiProperty({ example: 'Reckless driving' })
  @IsString()
  @MaxLength(100)
  reason: string;

  @ApiPropertyOptional({
    example: 'Driver was speeding on the Prithvi Highway.',
  })
  @IsOptional()
  @IsString()
  @MaxLength(1000)
  description?: string;
}
