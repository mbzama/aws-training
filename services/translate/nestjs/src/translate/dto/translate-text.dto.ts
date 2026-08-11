import { ApiProperty } from '@nestjs/swagger';
import { IsBoolean, IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class TranslateTextDto {
  @ApiProperty({ description: 'Text to translate', example: 'Hello, world!' })
  @IsString()
  @IsNotEmpty()
  text: string;

  @ApiProperty({ description: 'Source language code', example: 'en' })
  @IsString()
  @IsNotEmpty()
  sourceLanguageCode: string;

  @ApiProperty({ description: 'Target language code', example: 'fr' })
  @IsString()
  @IsNotEmpty()
  targetLanguageCode: string;

  @ApiProperty({
    description:
      'Whether to apply the exclude-list-v1 custom terminology to this translation',
    default: true,
    required: false,
  })
  @IsOptional()
  @IsBoolean()
  useCustomTerminology?: boolean = true;
}
