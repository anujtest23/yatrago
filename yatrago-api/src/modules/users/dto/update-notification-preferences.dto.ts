import { IsBoolean, IsOptional, ValidateNested } from 'class-validator';
import { Type } from 'class-transformer';
import { ApiPropertyOptional } from '@nestjs/swagger';

// Per-channel toggles for one category. All optional so a client can flip a
// single switch.
class ChannelPrefsDto {
  @ApiPropertyOptional() @IsOptional() @IsBoolean() push?: boolean;
  @ApiPropertyOptional() @IsOptional() @IsBoolean() email?: boolean;
  @ApiPropertyOptional() @IsOptional() @IsBoolean() sms?: boolean;
}

export class UpdateNotificationPreferencesDto {
  @ApiPropertyOptional({ type: ChannelPrefsDto })
  @IsOptional()
  @ValidateNested()
  @Type(() => ChannelPrefsDto)
  booking?: ChannelPrefsDto;

  @ApiPropertyOptional({ type: ChannelPrefsDto })
  @IsOptional()
  @ValidateNested()
  @Type(() => ChannelPrefsDto)
  payment?: ChannelPrefsDto;

  @ApiPropertyOptional({ type: ChannelPrefsDto })
  @IsOptional()
  @ValidateNested()
  @Type(() => ChannelPrefsDto)
  wallet?: ChannelPrefsDto;

  @ApiPropertyOptional({ type: ChannelPrefsDto })
  @IsOptional()
  @ValidateNested()
  @Type(() => ChannelPrefsDto)
  chat?: ChannelPrefsDto;

  @ApiPropertyOptional({ type: ChannelPrefsDto })
  @IsOptional()
  @ValidateNested()
  @Type(() => ChannelPrefsDto)
  promotions?: ChannelPrefsDto;

  @ApiPropertyOptional({ type: ChannelPrefsDto })
  @IsOptional()
  @ValidateNested()
  @Type(() => ChannelPrefsDto)
  security?: ChannelPrefsDto;
}
