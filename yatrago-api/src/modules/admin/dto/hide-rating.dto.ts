import { IsString, MaxLength } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class HideRatingDto {
  @ApiProperty({ example: 'Abusive language in review text' })
  @IsString()
  @MaxLength(500)
  reason: string;
}
