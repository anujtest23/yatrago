import { IsBoolean, IsIn, IsOptional } from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';
import { VISIBILITY_OPTIONS } from '../preferences';

export class UpdatePrivacySettingsDto {
  @ApiPropertyOptional({ enum: VISIBILITY_OPTIONS })
  @IsOptional()
  @IsIn(VISIBILITY_OPTIONS as unknown as string[])
  profileVisibility?: string;

  @ApiPropertyOptional({ enum: VISIBILITY_OPTIONS })
  @IsOptional()
  @IsIn(VISIBILITY_OPTIONS as unknown as string[])
  phoneVisibility?: string;

  @ApiPropertyOptional({ enum: VISIBILITY_OPTIONS })
  @IsOptional()
  @IsIn(VISIBILITY_OPTIONS as unknown as string[])
  rideVisibility?: string;

  @ApiPropertyOptional({ example: false })
  @IsOptional()
  @IsBoolean()
  marketingConsent?: boolean;

  @ApiPropertyOptional({ example: true })
  @IsOptional()
  @IsBoolean()
  analyticsConsent?: boolean;
}
