/**
 * Order Processor Worker
 *
 * Polls the main SQS queue and processes orders.
 * - Valid orders (status: 'pending') → processed and deleted from queue ✅
 * - Invalid orders (status: 'invalid', negative amount, empty items) → throws error
 *   The message is NOT deleted, so SQS retries it. After maxReceiveCount (3),
 *   SQS automatically moves the message to the Dead Letter Queue (DLQ).
 */

import * as dotenv from 'dotenv';
dotenv.config({ path: '.env.local' });

import { receiveMessages, deleteMessage, OrderMessage } from '../lib/sqs';
import { createLogger } from '../lib/logger';

const logger = createLogger('ORDER-PROCESSOR');

interface ValidationError {
  field: string;
  message: string;
}

function validateOrder(order: OrderMessage): ValidationError[] {
  const errors: ValidationError[] = [];

  if (!order.customerId || order.customerId.trim() === '') {
    errors.push({ field: 'customerId', message: 'Customer ID is required' });
  }

  if (order.amount <= 0) {
    errors.push({ field: 'amount', message: `Amount must be positive, got: ${order.amount}` });
  }

  if (!order.items || order.items.length === 0) {
    errors.push({ field: 'items', message: 'Order must contain at least one item' });
  }

  if (order.status === 'invalid') {
    errors.push({ field: 'status', message: 'Order has been marked as invalid' });
  }

  return errors;
}

async function processOrder(order: OrderMessage): Promise<void> {
  logger.info('📦 Processing order', {
    orderId: order.orderId,
    customerId: order.customerId,
    amount: order.amount,
    itemCount: order.items.length,
  });

  const errors = validateOrder(order);

  if (errors.length > 0) {
    logger.error('❌ Order validation failed — message will be retried and moved to DLQ', {
      orderId: order.orderId,
      validationErrors: errors,
    });
    throw new Error(`Order validation failed: ${errors.map(e => e.message).join('; ')}`);
  }

  // Simulate order processing (e.g., DB write, payment charge, etc.)
  await new Promise(resolve => setTimeout(resolve, 100));

  logger.info('✅ Order processed successfully', {
    orderId: order.orderId,
    customerId: order.customerId,
    amount: `$${order.amount.toFixed(2)}`,
    itemCount: order.items.length,
    processedAt: new Date().toISOString(),
  });
}

async function poll(): Promise<void> {
  const queueUrl = process.env.SQS_QUEUE_URL;

  if (!queueUrl) {
    logger.error('SQS_QUEUE_URL environment variable is not set. Exiting.');
    process.exit(1);
  }

  logger.info('🚀 Order Processor started', { queueUrl });

  while (true) {
    try {
      logger.debug('Polling for messages...', { queueUrl });
      const messages = await receiveMessages(queueUrl);

      if (messages.length === 0) {
        logger.debug('No messages received — waiting...');
        continue;
      }

      logger.info(`📬 Received ${messages.length} message(s)`);

      for (const message of messages) {
        const receiveCount = parseInt(message.Attributes?.ApproximateReceiveCount ?? '1', 10);
        logger.info(`Processing message (attempt #${receiveCount})`, { messageId: message.MessageId });

        let order: OrderMessage;

        try {
          order = JSON.parse(message.Body ?? '{}') as OrderMessage;
        } catch {
          logger.error('Failed to parse message body — sending to DLQ by not deleting', {
            messageId: message.MessageId,
            body: message.Body,
          });
          continue; // Don't delete → will be retried → DLQ
        }

        try {
          await processOrder(order);

          // ✅ Success: delete the message from the queue
          await deleteMessage(queueUrl, message.ReceiptHandle!);
          logger.info('🗑️  Message deleted from queue', { messageId: message.MessageId, orderId: order.orderId });
        } catch (err) {
          const error = err as Error;
          logger.warn('⚠️  Processing failed — message NOT deleted (will be retried)', {
            messageId: message.MessageId,
            orderId: order.orderId,
            attempt: receiveCount,
            error: error.message,
            note: receiveCount >= 3
              ? '🔴 Max retries reached — SQS will move to DLQ on next visibility timeout'
              : `Will retry ${3 - receiveCount} more time(s)`,
          });
          // Intentionally NOT deleting the message so SQS retries it
        }
      }
    } catch (err) {
      const error = err as Error;
      logger.error('Unexpected error in polling loop', { error: error.message });
      await new Promise(resolve => setTimeout(resolve, 5000)); // Back off on error
    }
  }
}

poll();
