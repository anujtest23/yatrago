import {
  IsString,
  IsInt,
  IsEnum,
  IsOptional,
  Min,
  Max,
  MaxLength,
} from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

enum VehicleType {
  motorcycle = 'motorcycle',
  car = 'car',
  suv = 'suv',
  microbus = 'microbus',
}

export class CreateVehicleDto {
  @ApiProperty({ example: 'Maruti' })
  @IsString()
  @MaxLength(50)
  make: string;

  @ApiProperty({ example: 'Alto' })
  @IsString()
  @MaxLength(50)
  model: string;

  @ApiProperty({ example: 2019 })
  @IsInt()
  @Min(1990)
  @Max(new Date().getFullYear() + 1)
  year: number;

  @ApiProperty({ example: 'BA 1 CHA 2345' })
  @IsString()
  @MaxLength(20)
  plateNumber: string;

  @ApiPropertyOptional({ example: 'White' })
  @IsOptional()
  @IsString()
  @MaxLength(30)
  color?: string;

  @ApiProperty({ enum: VehicleType, example: 'car' })
  @IsEnum(VehicleType)
  vehicleType: VehicleType;

  @ApiProperty({ example: 4 })
  @IsInt()
  @Min(1)
  @Max(50)
  totalSeats: number;
}
