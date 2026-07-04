import { IsOptional, IsString, MaxLength } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class CreateEmergencyContactDto {
  @ApiProperty({ example: 'Sita Sharma' })
  @IsString()
  @MaxLength(100)
  fullName: string;

  @ApiProperty({ example: '9800000000' })
  @IsString()
  @MaxLength(20)
  phoneNumber: string;

  @ApiPropertyOptional({ example: 'Sister' })
  @IsOptional()
  @IsString()
  @MaxLength(50)
  relationship?: string;
}
