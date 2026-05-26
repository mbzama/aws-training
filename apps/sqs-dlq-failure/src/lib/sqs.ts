import { SQSClient, SendMessageCommand, ReceiveMessageCommand, DeleteMessageCommand } from '@aws-sdk/client-sqs';

const sqsClientConfig: Record<string, unknown> = {
  region: process.env.AWS_REGION || 'us-east-1',
  credentials: {
    accessKeyId: process.env.AWS_ACCESS_KEY_ID || 'test',
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY || 'test',
  },
};

// Use LocalStack endpoint if configured
if (process.env.AWS_ENDPOINT_URL) {
  sqsClientConfig.endpoint = process.env.AWS_ENDPOINT_URL;
}

export const sqsClient = new SQSClient(sqsClientConfig);

export interface OrderMessage {
  orderId: string;
  customerId: string;
  amount: number;
  items: Array<{ productId: string; quantity: number; price: number }>;
  status: 'pending' | 'invalid';
  timestamp: string;
}

export async function sendToQueue(queueUrl: string, message: OrderMessage): Promise<string> {
  const command = new SendMessageCommand({
    QueueUrl: queueUrl,
    MessageBody: JSON.stringify(message),
    MessageAttributes: {
      OrderStatus: {
        DataType: 'String',
        StringValue: message.status,
      },
    },
  });

  const response = await sqsClient.send(command);
  return response.MessageId ?? '';
}

export async function receiveMessages(queueUrl: string, maxMessages = 10) {
  const command = new ReceiveMessageCommand({
    QueueUrl: queueUrl,
    MaxNumberOfMessages: maxMessages,
    WaitTimeSeconds: 20,       // Long polling
    VisibilityTimeout: 30,
    MessageAttributeNames: ['All'],
    AttributeNames: ['All'],
  });

  const response = await sqsClient.send(command);
  return response.Messages ?? [];
}

export async function deleteMessage(queueUrl: string, receiptHandle: string): Promise<void> {
  const command = new DeleteMessageCommand({
    QueueUrl: queueUrl,
    ReceiptHandle: receiptHandle,
  });

  await sqsClient.send(command);
}
