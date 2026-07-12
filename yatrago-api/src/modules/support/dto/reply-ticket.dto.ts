import { IsEnum, IsOptional, IsString, MaxLength } from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';
import { SupportStatus } from '@prisma/client';

export class ReplyTicketDto {
  @ApiPropertyOptional({ example: 'Thanks for reaching out — try again now.' })
  @IsOptional()
  @IsString()
  @MaxLength(2000)
  reply?: string;

  @ApiPropertyOptional({ enum: SupportStatus })
  @IsOptional()
  @IsEnum(SupportStatus)
  status?: SupportStatus;
}
