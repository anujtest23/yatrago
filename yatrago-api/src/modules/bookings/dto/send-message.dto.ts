import { IsString, IsUUID, MaxLength } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class SendMessageDto {
  @ApiProperty({ example: 'booking-uuid-here' })
  @IsUUID()
  bookingId: string;

  @ApiProperty({ example: 'I am 5 minutes away from the pickup point' })
  @IsString()
  @MaxLength(500)
  content: string;
}
