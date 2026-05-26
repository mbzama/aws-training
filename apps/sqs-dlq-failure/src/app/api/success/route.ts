import { NextResponse } from 'next/server';
import { sendToQueue, OrderMessage } from '@/lib/sqs';
import { appLogger } from '@/lib/logger';

export async function POST() {
  const queueUrl = process.env.SQS_QUEUE_URL;

  if (!queueUrl) {
    appLogger.error('SQS_QUEUE_URL environment variable is not set');
    return NextResponse.json({ error: 'SQS_QUEUE_URL not configured' }, { status: 500 });
  }

  const order: OrderMessage = {
    orderId: `ORD-${Date.now()}`,
    customerId: `CUST-${Math.floor(Math.random() * 1000)}`,
    amount: parseFloat((Math.random() * 500 + 10).toFixed(2)),
    items: [
      { productId: 'PROD-001', quantity: 2, price: 29.99 },
      { productId: 'PROD-042', quantity: 1, price: 89.99 },
    ],
    status: 'pending',
    timestamp: new Date().toISOString(),
  };

  try {
    const messageId = await sendToQueue(queueUrl, order);

    appLogger.info('✅ Valid order sent to SQS', {
      messageId,
      orderId: order.orderId,
      customerId: order.customerId,
      amount: order.amount,
    });

    return NextResponse.json({
      success: true,
      message: 'Order successfully queued',
      messageId,
      order,
    });
  } catch (error) {
    const err = error as Error;
    appLogger.error('Failed to send message to SQS', { error: err.message, orderId: order.orderId });
    return NextResponse.json({ error: 'Failed to send message', details: err.message }, { status: 500 });
  }
}
