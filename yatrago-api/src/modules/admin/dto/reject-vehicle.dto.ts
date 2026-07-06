import { IsString, MaxLength } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class RejectVehicleDto {
  @ApiProperty({
    example: 'Bluebook document is not legible. Please resubmit.',
  })
  @IsString()
  @MaxLength(500)
  reason: string;
}
