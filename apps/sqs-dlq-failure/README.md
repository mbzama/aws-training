# AWS SQS + Dead Letter Queue (DLQ) Demo

A Next.js application demonstrating AWS SQS message processing with automatic DLQ routing
for failed messages — including a deep explanation of **how and why messages move to the DLQ**.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [How Messages Move to the DLQ — Full Explanation](#how-messages-move-to-the-dlq--full-explanation)
   - [The Key Mechanic: Delete vs. No-Delete](#the-key-mechanic-delete-vs-no-delete)
   - [Visibility Timeout](#visibility-timeout)
   - [Redrive Policy & maxReceiveCount](#redrive-policy--maxreceivecount)
   - [Step-by-Step Message Lifecycle](#step-by-step-message-lifecycle)
   - [What SQS Tracks Internally](#what-sqs-tracks-internally)
3. [Project Structure](#project-structure)
4. [Queue Configuration](#queue-configuration)
5. [Quick Start](#quick-start)
6. [API Endpoints](#api-endpoints)
7. [Message Payloads](#message-payloads)
8. [Log Output Examples](#log-output-examples)
9. [Environment Variables](#environment-variables)
10. [Real AWS Deployment](#real-aws-deployment)

---

## Architecture Overview

```
                        ┌─────────────────────────────────────────────────────┐
                        │                   AWS SQS                           │
                        │                                                     │
  POST /api/success ───►│  orders-queue  ──────────────────────────────────► │──► Order Processor
  POST /api/fail    ───►│  (main queue)                                       │         │
                        │                                                     │    ✅ Valid?
                        │                                                     │    → delete msg
                        │                                                     │    → log success
                        │                                                     │
                        │                                                     │    ❌ Invalid?
                        │                                                     │    → DON'T delete
                        │                                                     │    → visibility
                        │                                                     │      timeout expires
                        │                                                     │    → retry (×3)
                        │                                                     │         │
                        │  orders-dlq  ◄──── RedrivePolicy ──────────────────│─────────┘
                        │  (dead letter)    maxReceiveCount: 3                │
                        │                                                     │
                        └─────────────────────────────────────────────────────┘
                                    │
                                    ▼
                            Failure Processor
                            → log failure report
                            → delete from DLQ
```

---

## How Messages Move to the DLQ — Full Explanation

Understanding the DLQ mechanism requires understanding three interlocking SQS concepts:
**delete**, **visibility timeout**, and **redrive policy**.

---

### The Key Mechanic: Delete vs. No-Delete

SQS uses a **consumer-driven deletion model**. When a consumer receives a message,
SQS does NOT automatically remove it. The message stays in the queue until the
consumer explicitly deletes it by calling `DeleteMessage`.

This is intentional — it protects against:
- Consumer crashes mid-processing
- Network failures between receive and delete
- Application bugs that silently swallow errors

**The rule that drives the DLQ:**

| Consumer action after processing | Result |
|----------------------------------|--------|
| Calls `DeleteMessage` ✅ | Message gone — success |
| Does NOT call `DeleteMessage` ❌ | Message becomes visible again after visibility timeout → retried |

In `order-processor.ts`:

```typescript
try {
  await processOrder(order);        // throws if validation fails

  // ✅ SUCCESS: explicitly delete the message
  await deleteMessage(queueUrl, message.ReceiptHandle!);

} catch (err) {
  // ❌ FAILURE: we intentionally do NOT call deleteMessage()
  // The message stays in the queue and will be retried
  logger.warn('Processing failed — message NOT deleted (will be retried)');
}
```

---

### Visibility Timeout

When a consumer calls `ReceiveMessage`, SQS temporarily **hides** that message from all
other consumers for a configurable duration — the **Visibility Timeout** (set to `30s`
in this project).

This prevents two consumers from processing the same message at the same time.

```
Timeline for a FAILED message:

t=0s   Consumer receives message → message becomes INVISIBLE (30s timeout starts)
t=5s   Consumer fails to process it (throws error)
       Consumer does NOT call DeleteMessage
t=30s  Visibility timeout expires → message becomes VISIBLE again
t=31s  Consumer picks it up again (attempt #2)
...
t=60s  Attempt #2 fails, timeout expires again
t=61s  Attempt #3 starts
t=90s  Attempt #3 fails
       ApproximateReceiveCount = 3  ← equals maxReceiveCount
       SQS moves message to DLQ ✅
```

The `ReceiptHandle` returned with each `ReceiveMessage` call is a one-time token used
for both `DeleteMessage` and `ChangeMessageVisibility`. A new handle is issued on each
re-delivery.

---

### Redrive Policy & maxReceiveCount

The **Redrive Policy** is a JSON config attached to the **source queue** (`orders-queue`)
that tells SQS: *"if a message has been received more than N times without being deleted,
move it to this other queue (the DLQ)"*.

This project sets it up in `src/scripts/setup-queues.ts`:

```typescript
const redrivePolicy = JSON.stringify({
  deadLetterTargetArn: dlqArn,  // ARN of orders-dlq
  maxReceiveCount: 3,            // move to DLQ after 3 failed attempts
});

await sqs.send(new CreateQueueCommand({
  QueueName: 'orders-queue',
  Attributes: {
    VisibilityTimeout: '30',
    RedrivePolicy: redrivePolicy,
  },
}));
```

SQS tracks the `ApproximateReceiveCount` attribute on each message internally.
No application code needs to count retries — SQS handles it entirely.

**DLQ requirements:**
- The DLQ must be created **before** the source queue (you need its ARN)
- Both queues must be in the same AWS account and region
- For FIFO queues, the DLQ must also be FIFO

---

### Step-by-Step Message Lifecycle

#### ✅ Happy Path (valid order from `/api/success`)

```
Step 1: POST /api/success
        └─► sendToQueue(queueUrl, { orderId: "ORD-123", status: "pending", amount: 149.98, ... })
            SQS assigns MessageId, stores message

Step 2: Order Processor polls with ReceiveMessage (long polling, WaitTimeSeconds: 20)
        └─► SQS returns message
            ApproximateReceiveCount = 1
            Message is now INVISIBLE (30s)

Step 3: validateOrder() — passes all checks
        └─► customerId present ✅
            amount > 0 ✅
            items.length > 0 ✅
            status !== 'invalid' ✅

Step 4: processOrder() succeeds

Step 5: deleteMessage(queueUrl, receiptHandle)
        └─► SQS permanently removes the message ✅

Log output:
  ✅ Order processed successfully { orderId: "ORD-123", amount: "$149.98" }
  🗑️  Message deleted from queue
```

#### ❌ Failure Path (invalid order from `/api/fail`)

```
Step 1: POST /api/fail
        └─► sendToQueue(queueUrl, { orderId: "INVALID-456", status: "invalid",
                                     customerId: "", amount: -99.99, items: [] })
            SQS assigns MessageId, stores message

Step 2: Order Processor receives message
        ApproximateReceiveCount = 1
        Message is INVISIBLE (30s)

Step 3: validateOrder() — FAILS
        └─► customerId is empty ❌
            amount = -99.99 (negative) ❌
            items = [] (empty) ❌
            status = 'invalid' ❌

Step 4: processOrder() throws Error("Order validation failed: ...")

Step 5: catch block — NO deleteMessage call
        └─► message stays in queue
        Log: ⚠️  Processing failed — will retry (attempt #1, 2 more left)

Step 6: t+30s — Visibility timeout expires
        Message becomes VISIBLE again
        ApproximateReceiveCount = 2

Step 7: Order Processor receives it again (attempt #2)
        Same validation, same failure, NOT deleted
        Log: ⚠️  Processing failed — will retry (attempt #2, 1 more left)

Step 8: t+60s — Visibility timeout expires again
        ApproximateReceiveCount = 3

Step 9: Order Processor receives it (attempt #3)
        Same failure, NOT deleted
        Log: ⚠️  Processing failed — Max retries reached, SQS will move to DLQ

Step 10: t+90s — Visibility timeout expires
         ApproximateReceiveCount (3) >= maxReceiveCount (3)
         ─────────────────────────────────────────────────
         SQS AUTOMATICALLY MOVES MESSAGE TO orders-dlq ✅
         ─────────────────────────────────────────────────
         Message is REMOVED from orders-queue
         Message APPEARS in orders-dlq

Step 11: Failure Processor polls orders-dlq
         Receives the failed message
         Log: 🚨 FAILED ORDER RECEIVED FROM DLQ
              { reasons: ["Invalid amount: -99.99", "No items in order", ...] }

Step 12: Failure Processor calls deleteMessage(dlqUrl, receiptHandle)
         Message permanently removed from DLQ ✅
```

---

### What SQS Tracks Internally

SQS automatically maintains these message attributes — accessible via
`AttributeNames: ['All']` in `ReceiveMessage`:

| Attribute | Description | Used in this project |
|-----------|-------------|----------------------|
| `ApproximateReceiveCount` | How many times this message has been received | Logged on each attempt |
| `ApproximateFirstReceiveTimestamp` | Epoch ms when first received | Logged in DLQ failure report |
| `SentTimestamp` | Epoch ms when sent | Logged in DLQ failure report |
| `MessageDeduplicationId` | FIFO dedup ID | N/A (Standard queue) |

The `ApproximateReceiveCount` is what SQS compares against `maxReceiveCount` to decide
when to invoke the redrive.

---

### Visual Summary

```
Message in orders-queue
         │
         ▼
  ReceiveMessage
  (ApproximateReceiveCount++)
         │
  ┌──────┴──────┐
  │             │
  ▼             ▼
Process      Process
 OK           FAILS
  │             │
  ▼             ▼
DeleteMsg    No Delete ──► Visibility Timeout expires ──► back to queue
  │                                                            │
  ▼                                               (repeat until count >= maxReceiveCount)
 Done ✅                                                       │
                                                               ▼
                                                      SQS Redrive → DLQ
                                                               │
                                                               ▼
                                                    Failure Processor
                                                    logs + deletes ✅
```

---

## Project Structure

```
sqs-dlq-failure/
├── src/
│   ├── app/
│   │   ├── layout.tsx                  ← App shell
│   │   ├── page.tsx                    ← Dashboard UI
│   │   └── api/
│   │       ├── success/route.ts        ← POST /api/success (valid order)
│   │       └── fail/route.ts           ← POST /api/fail   (invalid order)
│   ├── lib/
│   │   ├── sqs.ts                      ← SQS client + send/receive/delete helpers
│   │   └── logger.ts                   ← Winston logger factory
│   ├── workers/
│   │   ├── order-processor.ts          ← Main queue consumer
│   │   └── failure-processor.ts        ← DLQ consumer
│   └── scripts/
│       └── setup-queues.ts             ← Creates queues (DLQ first, then main)
├── docker-compose.yml                  ← LocalStack (SQS emulator)
├── .env.local                          ← LocalStack credentials & queue URLs
├── .env.example                        ← Template for real AWS
├── tsconfig.json                       ← Next.js TypeScript config
├── tsconfig.worker.json                ← CommonJS config for ts-node workers
└── package.json
```

---

## Queue Configuration

| Queue | Purpose | Retention | Notes |
|-------|---------|-----------|-------|
| `orders-dlq` | Dead Letter Queue | 14 days | Created first — its ARN feeds the redrive policy |
| `orders-queue` | Main processing queue | 1 day | `VisibilityTimeout: 30s`, `maxReceiveCount: 3` |

**Why create the DLQ first?**
The main queue's `RedrivePolicy` requires the DLQ's ARN at creation time.
The DLQ must exist before you can reference it.

---

## Quick Start

### Prerequisites
- Docker (for LocalStack)
- Node.js 18+

### 1. Install dependencies
```bash
npm install
```

### 2. Start LocalStack (SQS emulator)
```bash
npm run docker:up
```

### 3. Create the queues
```bash
npm run setup:queues
```

Expected output:
```
✅ DLQ created          { dlqUrl: "http://localhost:4566/000000000000/orders-dlq" }
DLQ ARN retrieved       { dlqArn: "arn:aws:sqs:us-east-1:000000000000:orders-dlq" }
✅ Main queue created   { queueUrl: "http://localhost:4566/000000000000/orders-queue", maxReceiveCount: 3 }
✅ Queue setup complete!
```

### 4. Run all three processes (separate terminals)

**Terminal 1 — Next.js API server:**
```bash
npm run dev
```

**Terminal 2 — Order Processor (main queue consumer):**
```bash
npm run worker:order
```

**Terminal 3 — Failure Processor (DLQ consumer):**
```bash
npm run worker:failure
```

### 5. Trigger the flows

**Happy path — valid order:**
```bash
curl -s -X POST http://localhost:3000/api/success | jq .
```

**Failure path — invalid order (will hit DLQ after 3 retries):**
```bash
curl -s -X POST http://localhost:3000/api/fail | jq .
```

> ⏱️ After sending a `/api/fail` request, watch Terminal 2 log 3 retry attempts
> (each separated by the 30s visibility timeout). Then watch Terminal 3 receive
> the message from the DLQ.

---

## API Endpoints

### `POST /api/success`

Sends a well-formed order to `orders-queue`. The Order Processor will validate it,
log success, and delete it from the queue.

**Response:**
```json
{
  "success": true,
  "message": "Order successfully queued",
  "messageId": "abc-123-...",
  "order": {
    "orderId": "ORD-1716000000000",
    "customerId": "CUST-42",
    "amount": 149.98,
    "items": [{ "productId": "PROD-001", "quantity": 2, "price": 29.99 }],
    "status": "pending",
    "timestamp": "2024-05-18T10:00:00.000Z"
  }
}
```

### `POST /api/fail`

Sends a deliberately broken order to `orders-queue`. The Order Processor will fail
validation on every attempt. After 3 receives without deletion, SQS moves it to the DLQ.

**Intentional defects in the payload:**

| Field | Invalid value | Why it fails |
|-------|---------------|--------------|
| `customerId` | `""` (empty string) | Customer lookup would fail |
| `amount` | `-99.99` | Can't charge a negative amount |
| `items` | `[]` (empty array) | Nothing to fulfil |
| `status` | `"invalid"` | Explicitly flagged as bad |

**Response:**
```json
{
  "success": true,
  "message": "Invalid order queued — will fail processing and move to DLQ after retries",
  "messageId": "def-456-...",
  "expectedBehavior": "Order Processor will reject this message. After 3 retries it will be sent to the DLQ."
}
```

---

## Message Payloads

### Valid Order
```json
{
  "orderId": "ORD-1716000000000",
  "customerId": "CUST-42",
  "amount": 149.98,
  "items": [
    { "productId": "PROD-001", "quantity": 2, "price": 29.99 },
    { "productId": "PROD-042", "quantity": 1, "price": 89.99 }
  ],
  "status": "pending",
  "timestamp": "2024-05-18T10:00:00.000Z"
}
```

### Invalid Order
```json
{
  "orderId": "INVALID-1716000000000",
  "customerId": "",
  "amount": -99.99,
  "items": [],
  "status": "invalid",
  "timestamp": "2024-05-18T10:00:00.000Z"
}
```

---

## Log Output Examples

### Order Processor — valid message received and processed
```
[2024-05-18 10:00:01] [ORDER-PROCESSOR] info:  📬 Received 1 message(s)
[2024-05-18 10:00:01] [ORDER-PROCESSOR] info:  Processing message (attempt #1) { messageId: "abc-123" }
[2024-05-18 10:00:01] [ORDER-PROCESSOR] info:  📦 Processing order { orderId: "ORD-...", amount: 149.98 }
[2024-05-18 10:00:01] [ORDER-PROCESSOR] info:  ✅ Order processed successfully { orderId: "ORD-...", amount: "$149.98" }
[2024-05-18 10:00:01] [ORDER-PROCESSOR] info:  🗑️  Message deleted from queue { messageId: "abc-123" }
```

### Order Processor — invalid message, retry 1/3
```
[2024-05-18 10:00:10] [ORDER-PROCESSOR] info:  Processing message (attempt #1) { messageId: "def-456" }
[2024-05-18 10:00:10] [ORDER-PROCESSOR] info:  📦 Processing order { orderId: "INVALID-...", amount: -99.99 }
[2024-05-18 10:00:10] [ORDER-PROCESSOR] error: ❌ Order validation failed
  {
    validationErrors: [
      { field: "customerId", message: "Customer ID is required" },
      { field: "amount",     message: "Amount must be positive, got: -99.99" },
      { field: "items",      message: "Order must contain at least one item" },
      { field: "status",     message: "Order has been marked as invalid" }
    ]
  }
[2024-05-18 10:00:10] [ORDER-PROCESSOR] warn:  ⚠️  Processing failed — message NOT deleted (will be retried)
  { attempt: 1, note: "Will retry 2 more time(s)" }
```

### Order Processor — attempt 3, max retries hit
```
[2024-05-18 10:01:10] [ORDER-PROCESSOR] warn:  ⚠️  Processing failed — message NOT deleted (will be retried)
  { attempt: 3, note: "🔴 Max retries reached — SQS will move to DLQ on next visibility timeout" }
```

### Failure Processor — message received from DLQ
```
[2024-05-18 10:01:40] [FAILURE-PROCESSOR] warn:  🔴 1 failed message(s) in DLQ — processing
[2024-05-18 10:01:40] [FAILURE-PROCESSOR] error: 🚨 FAILED ORDER RECEIVED FROM DLQ
  {
    orderId: "INVALID-1716000000000",
    amount: -99.99,
    itemCount: 0,
    sentTimestamp: "2024-05-18T10:00:05.000Z",
    receivedAt: "2024-05-18T10:01:40.000Z",
    reasons: [
      "Missing or empty customerId",
      "Invalid amount: -99.99 (must be positive)",
      "No items in order",
      "Order explicitly marked as invalid"
    ]
  }
[2024-05-18 10:01:40] [FAILURE-PROCESSOR] error: 💀 FAILURE SUMMARY
  {
    action: "REQUIRES_MANUAL_REVIEW",
    recommendedActions: [
      "Verify customer account status",
      "Check order payload integrity",
      "Contact customer if applicable",
      "Archive to failed-orders store"
    ]
  }
[2024-05-18 10:01:40] [FAILURE-PROCESSOR] info:  🗑️  Failed message removed from DLQ after logging
```

---

## Environment Variables

| Variable | Description | Default (LocalStack) |
|----------|-------------|----------------------|
| `AWS_REGION` | AWS region | `us-east-1` |
| `AWS_ACCESS_KEY_ID` | AWS access key | `test` |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key | `test` |
| `SQS_QUEUE_URL` | Main queue URL | `http://localhost:4566/000000000000/orders-queue` |
| `SQS_DLQ_URL` | DLQ URL | `http://localhost:4566/000000000000/orders-dlq` |
| `AWS_ENDPOINT_URL` | Override SQS endpoint | `http://localhost:4566` |

---

## Real AWS Deployment

1. Remove or comment out `AWS_ENDPOINT_URL` in `.env.local`
2. Set real IAM credentials with `sqs:*` permissions
3. Run `npm run setup:queues` — it will create the queues in AWS and print the real URLs
4. Copy the printed URLs into `SQS_QUEUE_URL` and `SQS_DLQ_URL`
5. Start the app and workers as normal

**Minimum IAM permissions required:**
```json
{
  "Effect": "Allow",
  "Action": [
    "sqs:CreateQueue",
    "sqs:GetQueueAttributes",
    "sqs:SetQueueAttributes",
    "sqs:SendMessage",
    "sqs:ReceiveMessage",
    "sqs:DeleteMessage"
  ],
  "Resource": "*"
}
```
