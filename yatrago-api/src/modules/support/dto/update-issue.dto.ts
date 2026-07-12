import { IsEnum, IsOptional, IsString, MaxLength } from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';
import { ReportStatus } from '@prisma/client';

export class UpdateIssueDto {
  @ApiPropertyOptional({ enum: ReportStatus })
  @IsOptional()
  @IsEnum(ReportStatus)
  status?: ReportStatus;

  @ApiPropertyOptional({ description: 'Admin/agent the issue is assigned to' })
  @IsOptional()
  @IsString()
  @MaxLength(120)
  assignedTo?: string;

  @ApiPropertyOptional({ example: 'Refunded the passenger and warned the driver.' })
  @IsOptional()
  @IsString()
  @MaxLength(2000)
  resolution?: string;
}
