import { IsString, Length, Matches } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class RefreshTokenDto {
  @ApiProperty({ description: 'Opaque refresh token issued at login/refresh' })
  @IsString()
  @Length(16, 512)
  // base64url alphabet only (also matches legacy JWT-style tokens) — rejects
  // control characters and oversized junk before it reaches any service code.
  @Matches(/^[A-Za-z0-9_.-]+$/, { message: 'Malformed refresh token' })
  refreshToken: string;
}
