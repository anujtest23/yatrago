import {
  IsBoolean,
  IsLatitude,
  IsLongitude,
  IsOptional,
} from 'class-validator';
import { Type } from 'class-transformer';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class UpdateLocationDto {
  @ApiProperty({ example: 27.7172 })
  @Type(() => Number)
  @IsLatitude()
  lat: number;

  @ApiProperty({ example: 85.324 })
  @Type(() => Number)
  @IsLongitude()
  lng: number;

  @ApiPropertyOptional({
    description: 'Device-reported mock-location flag (Android isMock)',
  })
  @IsOptional()
  @IsBoolean()
  isMock?: boolean;
}
