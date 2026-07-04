import { IsEnum, IsOptional, IsString, Matches } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export enum GrantableRole {
  admin = 'admin',
  super_admin = 'super_admin',
}

export class CreateAdminDto {
  @ApiProperty({ example: '+9779812345678', description: 'Phone of the user to grant admin access' })
  @IsString()
  @Matches(/^\+977[0-9]{10}$/, {
    message: 'Phone number must be a valid Nepal number starting with +977',
  })
  phoneNumber: string;

  @ApiProperty({ enum: GrantableRole, default: GrantableRole.admin, required: false })
  @IsOptional()
  @IsEnum(GrantableRole)
  role?: GrantableRole;
}
