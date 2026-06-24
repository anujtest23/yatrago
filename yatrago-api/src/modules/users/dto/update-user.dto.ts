import { IsString, IsOptional, IsEnum, IsDateString, MaxLength } from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';

enum Gender {
  male = 'male',
  female = 'female',
  other = 'other',
  prefer_not_to_say = 'prefer_not_to_say',
}

export class UpdateUserDto {
  @ApiPropertyOptional({ example: 'Ram Shrestha' })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  fullName?: string;

  @ApiPropertyOptional({ enum: Gender })
  @IsOptional()
  @IsEnum(Gender)
  gender?: Gender;

  @ApiPropertyOptional({ example: '1995-06-15' })
  @IsOptional()
  @IsDateString()
  dateOfBirth?: string;

  @ApiPropertyOptional({ example: 'ne' })
  @IsOptional()
  @IsString()
  language?: string;
}