import { IsEnum } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export enum DocumentSide {
  front = 'front',
  back = 'back',
}

export class UploadDocumentDto {
  @ApiProperty({ enum: DocumentSide, example: 'front' })
  @IsEnum(DocumentSide)
  side: DocumentSide;
}