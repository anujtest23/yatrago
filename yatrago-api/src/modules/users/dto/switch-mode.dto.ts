import { IsEnum } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export enum UserMode {
  passenger = 'passenger',
  driver = 'driver',
}

export class SwitchModeDto {
  @ApiProperty({ enum: UserMode, example: 'driver' })
  @IsEnum(UserMode, { message: 'Mode must be either passenger or driver' })
  mode: UserMode;
}
