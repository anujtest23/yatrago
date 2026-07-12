import { IsUUID } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class VerifyTopUpDto {
  @ApiProperty({ description: 'The paymentId returned by initiate' })
  @IsUUID()
  paymentId: string;
}
