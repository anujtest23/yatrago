import {
  ArrayMaxSize,
  IsArray,
  IsEnum,
  IsOptional,
  IsString,
  Matches,
  IsUUID,
  MaxLength,
  MinLength,
} from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IssueCategory } from '@prisma/client';

export class CreateIssueReportDto {
  @ApiProperty({ enum: IssueCategory })
  @IsEnum(IssueCategory)
  category: IssueCategory;

  @ApiProperty({ example: 'The driver never showed up at the pickup point.' })
  @IsString()
  @MinLength(10)
  @MaxLength(2000)
  description: string;

  @ApiPropertyOptional({ description: 'Related booking, if any' })
  @IsOptional()
  @IsUUID('4')
  bookingId?: string;

  @ApiPropertyOptional({ description: 'Related ride, if any' })
  @IsOptional()
  @IsUUID('4')
  rideId?: string;

  @ApiPropertyOptional({
    type: [String],
    description: 'Screenshot paths returned by POST /support/attachments',
  })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(5)
  @Matches(/^\/uploads\/[A-Za-z0-9._-]+$/, {
    each: true,
    message: 'attachments must be uploaded via /support/attachments',
  })
  attachments?: string[];
}
