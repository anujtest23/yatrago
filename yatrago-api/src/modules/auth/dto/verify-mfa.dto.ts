import { IsString, Length, Matches } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class VerifyMfaDto {
  @ApiProperty({ description: 'mfaToken returned by verify-otp' })
  @IsString()
  @Length(16, 512)
  @Matches(/^[A-Za-z0-9_.-]+$/, { message: 'Malformed MFA token' })
  mfaToken: string;

  @ApiProperty({ example: '123456' })
  @IsString()
  @Matches(/^\d{6}$/, { message: 'Code must be 6 digits' })
  code: string;
}
