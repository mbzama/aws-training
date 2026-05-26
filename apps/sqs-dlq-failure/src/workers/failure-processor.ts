/**
 * Failure Processor Worker
 *
 * Polls the Dead Letter Queue (DLQ) for messages that failed processing
 * in the Order Processor after all retries were exhausted.
 *
 * Responsibilities:
 * - Log failed orders with full context for investigation
 * - Record failure metrics / alerting hooks
 * - Archive or take corrective action (e.g., notify support team)
 */

import * as dotenv from 'dotenv';
dotenv.config({ path: '.env.local' });

import { receiveMessages, deleteMessage, OrderMessage } from '../lib/sqs';
import { createLogger } from '../lib/logger';

const logger = createLogger('FAILURE-PROCESSOR');

interface FailureReport {
  orderId: string;
  customerId: string | undefined;
  amount: number;
  itemCount: number;
  timestamp: string;
  receivedAt: string;
  sqsMessageId: string | undefined;
  approximateFirstReceiveTimestamp: string | undefined;
  sentTimestamp: string | undefined;
  reasons: string[];
}

function analyzeFailure(order: OrderMessage): string[] {
  const reasons: string[] = [];

  if (!order.customerId || order.customerId.trim() === '') {
    reasons.push('Missing or empty customerId');
  }

  if (order.amount <= 0) {
    reasons.push(`Invalid amount: ${order.amount} (must be positive)`);
  }

  if (!order.items || order.items.length === 0) {
    reasons.push('No items in order');
  }

  if (order.status === 'invalid') {
    reasons.push('Order explicitly marked as invalid');
  }

  if (reasons.length === 0) {
    reasons.push('Unknown failure reason — review Order Processor logs');
  }

  return reasons;
}

async function processFailure(order: OrderMessage, sqsMessageId: string | undefined, attributes: Record<string, string>): Promise<void> {
  const reasons = analyzeFailure(order);

  const report: FailureReport = {
    orderId: order.orderId,
    customerId: order.customerId || undefined,
    amount: order.amount,
    itemCount: order.items?.length ?? 0,
    timestamp: order.timestamp,
    receivedAt: new Date().toISOString(),
    sqsMessageId,
    approximateFirstReceiveTimestamp: attributes.ApproximateFirstReceiveTimestamp
      ? new Date(parseInt(attributes.ApproximateFirstReceiveTimestamp)).toISOString()
      : undefined,
    sentTimestamp: attributes.SentTimestamp
      ? new Date(parseInt(attributes.SentTimestamp)).toISOString()
      : undefined,
    reasons,
  };

  logger.error('🚨 FAILED ORDER RECEIVED FROM DLQ', report);

  // Structured failure log for monitoring / alerting integration
  logger.error('💀 FAILURE SUMMARY', {
    orderId: order.orderId,
    failureReasons: reasons,
    action: 'REQUIRES_MANUAL_REVIEW',
    recommendedActions: [
      'Verify customer account status',
      'Check order payload integrity',
      'Contact customer if applicable',
      'Archive to failed-orders store',
    ],
  });
}

async function poll(): Promise<void> {
  const dlqUrl = process.env.SQS_DLQ_URL;

  if (!dlqUrl) {
    logger.error('SQS_DLQ_URL environment variable is not set. Exiting.');
    process.exit(1);
  }

  logger.info('🚀 Failure Processor started — monitoring DLQ', { dlqUrl });

  while (true) {
    try {
      logger.debug('Polling DLQ for failed messages...', { dlqUrl });
      const messages = await receiveMessages(dlqUrl);

      if (messages.length === 0) {
        logger.debug('DLQ is empty — all is well 🟢');
        continue;
      }

      logger.warn(`🔴 ${messages.length} failed message(s) in DLQ — processing`);

      for (const message of messages) {
        let order: OrderMessage;

        try {
          order = JSON.parse(message.Body ?? '{}') as OrderMessage;
        } catch {
          logger.error('Cannot parse DLQ message body', {
            messageId: message.MessageId,
            body: message.Body,
          });
          // Delete unparseable messages after logging
          await deleteMessage(dlqUrl, message.ReceiptHandle!);
          continue;
        }

        await processFailure(order, message.MessageId, message.Attributes as Record<string, string> ?? {});

        // Delete from DLQ after handling (prevents reprocessing)
        await deleteMessage(dlqUrl, message.ReceiptHandle!);
        logger.info('🗑️  Failed message removed from DLQ after logging', {
          messageId: message.MessageId,
          orderId: order.orderId,
        });
      }
    } catch (err) {
      const error = err as Error;
      logger.error('Unexpected error in DLQ polling loop', { error: error.message });
      await new Promise(resolve => setTimeout(resolve, 5000));
    }
  }
}

poll();
