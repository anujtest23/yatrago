import { IsEnum } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export enum ReportStatusAction {
  investigating = 'investigating',
  resolved = 'resolved',
  dismissed = 'dismissed',
}

export class UpdateReportStatusDto {
  @ApiProperty({ enum: ReportStatusAction, example: 'investigating' })
  @IsEnum(ReportStatusAction)
  status: ReportStatusAction;
}
