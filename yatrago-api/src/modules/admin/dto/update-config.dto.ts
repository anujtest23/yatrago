import { IsNumber, IsString } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class UpdateConfigDto {
  @ApiProperty({ example: 'commission_percent' })
  @IsString()
  key: string;

  @ApiProperty({ example: 12 })
  @IsNumber()
  value: number;
}
