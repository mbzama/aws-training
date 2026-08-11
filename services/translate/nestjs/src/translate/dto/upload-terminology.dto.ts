import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsIn, IsOptional, IsString } from 'class-validator';

export class UploadTerminologyDto {
  @ApiPropertyOptional({
    description: 'Human readable description of this terminology upload',
  })
  @IsOptional()
  @IsString()
  description?: string;

  @ApiPropertyOptional({
    description:
      'Format of the uploaded file. Inferred from the file extension when omitted.',
    enum: ['CSV', 'TMX', 'TSV'],
  })
  @IsOptional()
  @IsIn(['CSV', 'TMX', 'TSV'])
  format?: 'CSV' | 'TMX' | 'TSV';
}
