/**
 * Setup Script: Creates SQS queues in LocalStack (or AWS)
 *
 * Creates:
 *   1. orders-dlq     — Dead Letter Queue
 *   2. orders-queue   — Main queue with DLQ redrive policy (maxReceiveCount: 3)
 */

import * as dotenv from 'dotenv';
dotenv.config({ path: '.env.local' });

import {
  SQSClient,
  CreateQueueCommand,
  GetQueueAttributesCommand,
  SetQueueAttributesCommand,
} from '@aws-sdk/client-sqs';
import { createLogger } from '../lib/logger';

const logger = createLogger('SETUP');

const clientConfig: Record<string, unknown> = {
  region: process.env.AWS_REGION || 'us-east-1',
  credentials: {
    accessKeyId: process.env.AWS_ACCESS_KEY_ID || 'test',
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY || 'test',
  },
};

if (process.env.AWS_ENDPOINT_URL) {
  clientConfig.endpoint = process.env.AWS_ENDPOINT_URL;
}

const sqs = new SQSClient(clientConfig);

async function createDLQ(): Promise<string> {
  logger.info('Creating DLQ: orders-dlq');

  const response = await sqs.send(new CreateQueueCommand({
    QueueName: 'orders-dlq',
    Attributes: {
      MessageRetentionPeriod: '1209600', // 14 days
    },
  }));

  const dlqUrl = response.QueueUrl!;
  logger.info('✅ DLQ created', { dlqUrl });
  return dlqUrl;
}

async function getDLQArn(dlqUrl: string): Promise<string> {
  const response = await sqs.send(new GetQueueAttributesCommand({
    QueueUrl: dlqUrl,
    AttributeNames: ['QueueArn'],
  }));

  return response.Attributes?.QueueArn ?? '';
}

async function createMainQueue(dlqArn: string): Promise<string> {
  logger.info('Creating main queue: orders-queue');

  const redrivePolicy = JSON.stringify({
    deadLetterTargetArn: dlqArn,
    maxReceiveCount: 3,   // Move to DLQ after 3 failed processing attempts
  });

  const response = await sqs.send(new CreateQueueCommand({
    QueueName: 'orders-queue',
    Attributes: {
      VisibilityTimeout: '30',
      MessageRetentionPeriod: '86400',   // 1 day
      ReceiveMessageWaitTimeSeconds: '20', // Long polling
      RedrivePolicy: redrivePolicy,
    },
  }));

  const queueUrl = response.QueueUrl!;
  logger.info('✅ Main queue created with DLQ redrive policy', {
    queueUrl,
    dlqArn,
    maxReceiveCount: 3,
  });

  return queueUrl;
}

async function main() {
  logger.info('🚀 Setting up SQS queues', {
    endpoint: process.env.AWS_ENDPOINT_URL || 'AWS',
    region: process.env.AWS_REGION || 'us-east-1',
  });

  try {
    const dlqUrl = await createDLQ();
    const dlqArn = await getDLQArn(dlqUrl);
    logger.info('DLQ ARN retrieved', { dlqArn });

    const queueUrl = await createMainQueue(dlqArn);

    logger.info('✅ Queue setup complete!');
    logger.info('📋 Update your .env.local with:', {
      SQS_QUEUE_URL: queueUrl,
      SQS_DLQ_URL: dlqUrl,
    });
  } catch (err) {
    const error = err as Error;
    logger.error('❌ Failed to set up queues', { error: error.message });
    process.exit(1);
  }
}

main();
