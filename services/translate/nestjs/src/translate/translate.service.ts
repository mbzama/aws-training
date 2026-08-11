import {
  BadRequestException,
  Injectable,
  InternalServerErrorException,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  GetTerminologyCommand,
  ImportTerminologyCommand,
  ResourceNotFoundException,
  TerminologyDataFormat,
  TranslateClient,
  TranslateClientConfig,
  TranslateTextCommand,
} from '@aws-sdk/client-translate';
import { fromIni } from '@aws-sdk/credential-providers';
import { AppConfig } from '../config/configuration';

export interface UploadTerminologyOptions {
  description?: string;
  format?: TerminologyDataFormat;
}

@Injectable()
export class TranslateService {
  private readonly logger = new Logger(TranslateService.name);
  private readonly client: TranslateClient;
  private readonly terminologyName: string;

  constructor(private readonly configService: ConfigService<AppConfig, true>) {
    const aws = this.configService.get('aws', { infer: true });
    this.terminologyName = this.configService.get('terminologyName', {
      infer: true,
    });

    const clientConfig: TranslateClientConfig = { region: aws.region };

    if (aws.accessKeyId && aws.secretAccessKey) {
      // Credentials passed explicitly (e.g. exported in the terminal).
      clientConfig.credentials = {
        accessKeyId: aws.accessKeyId,
        secretAccessKey: aws.secretAccessKey,
        sessionToken: aws.sessionToken,
      };
    } else if (aws.profile) {
      // Read credentials from a named profile in ~/.aws/credentials.
      clientConfig.credentials = fromIni({ profile: aws.profile });
    }
    // Otherwise leave `credentials` unset so the AWS SDK's default provider
    // chain resolves them (env vars, AWS_PROFILE, EC2/ECS/Lambda role, etc.).

    this.client = new TranslateClient(clientConfig);
  }

  private inferFormat(fileName: string): TerminologyDataFormat {
    const extension = fileName.split('.').pop()?.toUpperCase();
    if (extension === 'CSV' || extension === 'TMX' || extension === 'TSV') {
      return extension;
    }
    throw new BadRequestException(
      `Could not infer terminology format from file "${fileName}". Provide "format" explicitly (CSV, TMX or TSV).`,
    );
  }

  async uploadTerminology(
    file: Express.Multer.File,
    options: UploadTerminologyOptions = {},
  ) {
    if (!file?.buffer?.length) {
      throw new BadRequestException(
        'A non-empty terminology file is required.',
      );
    }

    const format = options.format ?? this.inferFormat(file.originalname);

    try {
      const result = await this.client.send(
        new ImportTerminologyCommand({
          Name: this.terminologyName,
          MergeStrategy: 'OVERWRITE',
          Description: options.description,
          TerminologyData: {
            File: file.buffer,
            Format: format,
          },
        }),
      );

      this.logger.log(
        `Uploaded custom terminology "${this.terminologyName}" (${format})`,
      );

      return result.TerminologyProperties;
    } catch (error) {
      this.logger.error(
        `Failed to upload custom terminology "${this.terminologyName}"`,
        error instanceof Error ? error.stack : undefined,
      );
      throw new InternalServerErrorException(
        `Failed to upload custom terminology: ${(error as Error).message}`,
      );
    }
  }

  async getTerminology() {
    try {
      const result = await this.client.send(
        new GetTerminologyCommand({
          Name: this.terminologyName,
          TerminologyDataFormat: 'CSV',
        }),
      );

      return {
        properties: result.TerminologyProperties,
        downloadUrl: result.TerminologyDataLocation?.Location,
      };
    } catch (error) {
      if (error instanceof ResourceNotFoundException) {
        throw new NotFoundException(
          `Custom terminology "${this.terminologyName}" has not been uploaded yet.`,
        );
      }
      this.logger.error(
        `Failed to read custom terminology "${this.terminologyName}"`,
        error instanceof Error ? error.stack : undefined,
      );
      throw new InternalServerErrorException(
        `Failed to read custom terminology: ${(error as Error).message}`,
      );
    }
  }

  async translateText(
    text: string,
    sourceLanguageCode: string,
    targetLanguageCode: string,
    useCustomTerminology = true,
  ) {
    try {
      const result = await this.client.send(
        new TranslateTextCommand({
          Text: text,
          SourceLanguageCode: sourceLanguageCode,
          TargetLanguageCode: targetLanguageCode,
          TerminologyNames: useCustomTerminology
            ? [this.terminologyName]
            : undefined,
        }),
      );

      return {
        translatedText: result.TranslatedText,
        sourceLanguageCode: result.SourceLanguageCode,
        targetLanguageCode: result.TargetLanguageCode,
        appliedTerminologies: result.AppliedTerminologies,
      };
    } catch (error) {
      this.logger.error(
        'Failed to translate text',
        error instanceof Error ? error.stack : undefined,
      );
      throw new InternalServerErrorException(
        `Failed to translate text: ${(error as Error).message}`,
      );
    }
  }
}
