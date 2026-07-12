import { ApiProperty } from '@nestjs/swagger';
import { IsString, MinLength, MaxLength } from 'class-validator';

export class SendMessageDto {
  @ApiProperty({ example: 'Hi, I am waiting near the main gate.' })
  @IsString()
  @MinLength(1)
  @MaxLength(2000)
  content: string;
}
