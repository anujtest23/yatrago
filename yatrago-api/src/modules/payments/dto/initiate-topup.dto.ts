import { IsInt, Max, Min } from 'class-validator';
import { Type } from 'class-transformer';
import { ApiProperty } from '@nestjs/swagger';

export class InitiateTopUpDto {
  @ApiProperty({
    example: 1000,
    description: 'Whole-rupee (NPR) amount to load into the wallet',
  })
  @Type(() => Number)
  @IsInt({ message: 'Amount must be a whole number of rupees' })
  @Min(1)
  @Max(1_000_000)
  amount: number;
}
