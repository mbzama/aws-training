import {
  Body,
  Controller,
  Get,
  Post,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiBody, ApiConsumes, ApiOperation, ApiTags } from '@nestjs/swagger';
import { TranslateService } from './translate.service';
import { TranslateTextDto } from './dto/translate-text.dto';
import { UploadTerminologyDto } from './dto/upload-terminology.dto';

@ApiTags('translate')
@Controller()
export class TranslateController {
  constructor(private readonly translateService: TranslateService) {}

  @Post('terminology')
  @ApiOperation({
    summary: 'Upload (create/update) the exclude-list-v1 custom terminology',
  })
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        file: { type: 'string', format: 'binary' },
        description: { type: 'string' },
        format: { type: 'string', enum: ['CSV', 'TMX', 'TSV'] },
      },
      required: ['file'],
    },
  })
  @UseInterceptors(FileInterceptor('file'))
  uploadTerminology(
    @UploadedFile() file: Express.Multer.File,
    @Body() dto: UploadTerminologyDto,
  ) {
    return this.translateService.uploadTerminology(file, {
      description: dto.description,
      format: dto.format,
    });
  }

  @Get('terminology')
  @ApiOperation({
    summary:
      'Read metadata and download link for the exclude-list-v1 custom terminology',
  })
  getTerminology() {
    return this.translateService.getTerminology();
  }

  @Post('translate')
  @ApiOperation({
    summary:
      'Translate text from a source to a destination language, applying the exclude-list-v1 custom terminology',
  })
  translateText(@Body() dto: TranslateTextDto) {
    return this.translateService.translateText(
      dto.text,
      dto.sourceLanguageCode,
      dto.targetLanguageCode,
      dto.useCustomTerminology,
    );
  }
}
