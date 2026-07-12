import { IsOptional, IsString, Matches, MaxLength } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class CreateEmergencyContactDto {
  @ApiProperty({ example: 'Sita Sharma' })
  @IsString()
  @MaxLength(100)
  fullName: string;

  @ApiProperty({ example: '+9779800000000' })
  @IsString()
  // Accept local (98XXXXXXXX) or E.164 (+9779XXXXXXXXX) forms.
  @Matches(/^\+?\d{7,15}$/, {
    message: 'Enter a valid phone number (7-15 digits, optional +)',
  })
  phoneNumber: string;

  @ApiPropertyOptional({ example: 'Sister' })
  @IsOptional()
  @IsString()
  @MaxLength(50)
  relationship?: string;
}
