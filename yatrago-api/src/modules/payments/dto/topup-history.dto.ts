import { IsInt, IsOptional, IsUUID, Max, Min } from 'class-validator';
import { Type } from 'class-transformer';
import { ApiPropertyOptional } from '@nestjs/swagger';

export class TopupHistoryDto {
  @ApiPropertyOptional({
    description: 'Page size (1–50)',
    default: 20,
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(50)
  limit?: number = 20;

  @ApiPropertyOptional({
    description: 'Cursor = id of the last item from the previous page',
  })
  @IsOptional()
  @IsUUID()
  cursor?: string;
}
