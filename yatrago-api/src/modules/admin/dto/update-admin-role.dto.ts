import { IsEnum } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';
import { GrantableRole } from './create-admin.dto';

export class UpdateAdminRoleDto {
  @ApiProperty({ enum: GrantableRole })
  @IsEnum(GrantableRole)
  role: GrantableRole;
}
