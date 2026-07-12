import {
  ArrayMaxSize,
  IsArray,
  IsIn,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
  MinLength,
} from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export const SUPPORT_CATEGORIES = [
  'general',
  'account',
  'payment',
  'booking',
  'technical',
  'feedback',
] as const;

export class CreateSupportTicketDto {
  @ApiProperty({ enum: SUPPORT_CATEGORIES })
  @IsIn(SUPPORT_CATEGORIES)
  category: string;

  @ApiProperty({ example: 'Cannot update my profile photo' })
  @IsString()
  @MinLength(3)
  @MaxLength(150)
  subject: string;

  @ApiProperty({ example: 'Every time I try to upload a photo it fails with…' })
  @IsString()
  @MinLength(10)
  @MaxLength(2000)
  description: string;

  @ApiPropertyOptional({
    type: [String],
    description: 'Screenshot paths returned by POST /support/attachments',
  })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(5)
  // Only server-issued upload paths — never arbitrary external URLs.
  @Matches(/^\/uploads\/[A-Za-z0-9._-]+$/, {
    each: true,
    message: 'attachments must be uploaded via /support/attachments',
  })
  attachments?: string[];
}
