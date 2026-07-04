import { IsIn, IsNumber, IsPositive, IsString, MaxLength } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class RequestPayoutDto {
  @ApiProperty({ example: 1500, description: 'Amount in NPR to withdraw' })
  @IsNumber()
  @IsPositive()
  amount: number;

  @ApiProperty({ enum: ['esewa', 'khalti', 'bank'], example: 'esewa' })
  @IsString()
  @IsIn(['esewa', 'khalti', 'bank'])
  method: string;

  @ApiProperty({
    example: '9800000000',
    description: 'eSewa/Khalti ID or bank account number',
  })
  @IsString()
  @MaxLength(100)
  accountReference: string;
}
