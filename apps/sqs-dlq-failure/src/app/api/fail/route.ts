import { NextResponse } from 'next/server';
import { sendToQueue, OrderMessage } from '@/lib/sqs';
import { appLogger } from '@/lib/logger';

export async function POST() {
  const queueUrl = process.env.SQS_QUEUE_URL;

  if (!queueUrl) {
    appLogger.error('SQS_QUEUE_URL environment variable is not set');
    return NextResponse.json({ error: 'SQS_QUEUE_URL not configured' }, { status: 500 });
  }

  // Intentionally invalid order: negative amount, empty items, invalid status
  const invalidOrder: OrderMessage = {
    orderId: `INVALID-${Date.now()}`,
    customerId: '',                      // ❌ missing customer
    amount: -99.99,                      // ❌ negative amount
    items: [],                           // ❌ empty items
    status: 'invalid',                   // ❌ invalid status marker
    timestamp: new Date().toISOString(),
  };

  try {
    const messageId = await sendToQueue(queueUrl, invalidOrder);

    appLogger.warn('⚠️  Invalid order sent to SQS (will be retried and moved to DLQ)', {
      messageId,
      orderId: invalidOrder.orderId,
      reason: 'Negative amount, missing customerId, empty items',
    });

    return NextResponse.json({
      success: true,
      message: 'Invalid order queued — will fail processing and move to DLQ after retries',
      messageId,
      order: invalidOrder,
      expectedBehavior: 'Order Processor will reject this message. After 3 retries it will be sent to the DLQ.',
    });
  } catch (error) {
    const err = error as Error;
    appLogger.error('Failed to send invalid message to SQS', { error: err.message });
    return NextResponse.json({ error: 'Failed to send message', details: err.message }, { status: 500 });
  }
}
