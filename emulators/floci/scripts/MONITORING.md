# Real-Time Monitoring Scripts

Monitor your Event Booking Platform in real-time across all AWS services (CloudWatch, DynamoDB, SQS, S3).

## Available Scripts

| Script | Purpose | Refresh | What It Shows |
|--------|---------|---------|---------------|
| **watch-logs.sh** | CloudWatch Logs | Real-time | Lambda function execution logs |
| **watch-bookings.sh** | DynamoDB Bookings | 2 sec | Booking data, status changes |
| **watch-events.sh** | DynamoDB Events | 3 sec | Available events catalog |
| **watch-sqs.sh** | SQS Queue | 2 sec | Messages waiting to be processed |
| **watch-s3.sh** | S3 Buckets | 2 sec | Uploaded tickets & frontend files |
| **watch-all.sh** | Launch All | - | Starts all 5 monitors (Windows/Linux/macOS) |

---

## Quick Start: Watch Everything

**Option 1: Automatic (All-in-One)**

```bash
bash scripts/watch-all.sh
```

This launches all 5 monitors automatically in separate windows/panes.

**Option 2: Manual (5 Separate Terminals)**

```bash
# Terminal 1: Lambda logs
bash scripts/watch-logs.sh

# Terminal 2: Booking data
bash scripts/watch-bookings.sh

# Terminal 3: Events catalog
bash scripts/watch-events.sh

# Terminal 4: SQS queue
bash scripts/watch-sqs.sh

# Terminal 5: S3 buckets
bash scripts/watch-s3.sh
```

---

## Individual Scripts

### 1. watch-logs.sh — CloudWatch Logs

**Real-time Lambda function logs**

```bash
bash scripts/watch-logs.sh
```

**Output:**
```
[INFO] Retrieving events from DynamoDB...
[INFO] Found 4 events
[INFO] Creating booking record...
[INFO] Publishing SNS notification...
[INFO] Queuing ticket generation...
```

**Use when:** Testing Lambda functions, debugging errors

---

### 2. watch-bookings.sh — DynamoDB Bookings

**View all user bookings and status changes**

```bash
bash scripts/watch-bookings.sh
```

**Output:**
```
========================================
DynamoDB: Bookings Table
Last updated: 2026-06-10 14:32:15
==========================================

Total bookings: 3

Booking ID                           User ID         Event ID                                Status
--------                             --------        --------                                ------
BOOK-20260610T143200Z-abc123         user-001        event-001                               CONFIRMED
BOOK-20260610T143215Z-def456         user-002        event-002                               PROCESSING
BOOK-20260610T143230Z-ghi789         user-001        event-003                               PENDING

Status Breakdown:
  CONFIRMED: 1
  PROCESSING: 1
  PENDING: 1
```

**Use when:** Checking booking progress, verifying status changes

---

### 3. watch-events.sh — DynamoDB Events

**View the event catalog**

```bash
bash scripts/watch-events.sh
```

**Output:**
```
========================================
DynamoDB: Events Table
Last updated: 2026-06-10 14:32:15
==========================================

Total events: 4

Event ID     Event Name                          Date         Ticket Price
--------     ----------                          ----         -----------
event-001    Summer Music Festival 2026          2026-07-15   $99.99
event-002    Tech Conference 2026                2026-09-20   $299.99
event-003    Food Carnival 2026                  2026-08-10   $49.99
event-004    Basketball Championship 2026        2026-06-15   $150.00
```

**Use when:** Verifying events are loaded, checking ticket prices

---

### 4. watch-sqs.sh — SQS Queue

**Monitor messages waiting for ticket generation**

```bash
bash scripts/watch-sqs.sh
```

**Output:**
```
========================================
SQS: BookingQueue Monitor
Last updated: 2026-06-10 14:32:15
==========================================

Queue URL: http://localhost:4566/000000000000/us-east-1/BookingQueue

Message Count Summary:
  Total messages: 2
  Visible (waiting): 2
  Not visible (being processed): 0

Messages in queue: 2

Message Details:
---
MessageId: abc-123-def
ReceiptHandle: AQEBwu...
Body:
  bookingId: BOOK-20260610T143230Z-ghi789
  userId: user-001
  eventId: event-003
  quantity: 1
  totalPrice: 49.99
  userEmail: user@example.com
  createdAt: 2026-06-10T14:32:30Z
```

**Use when:** Checking async job queue, verifying message flow

---

### 5. watch-s3.sh — S3 Buckets

**Monitor uploaded tickets and frontend files**

```bash
bash scripts/watch-s3.sh
```

**Output:**
```
========================================
S3: Buckets Monitor
Last updated: 2026-06-10 14:32:15
==========================================

--- Tickets Bucket (event-tickets-000000000000) ---
Total ticket files: 3

Uploaded tickets:
  tickets/user-001/BOOK-20260610T143200Z-abc123.pdf (24576 bytes, 2026-06-10 14:32:15)
  tickets/user-002/BOOK-20260610T143215Z-def456.pdf (24576 bytes, 2026-06-10 14:32:20)
  tickets/user-001/BOOK-20260610T143230Z-ghi789.pdf (24576 bytes, 2026-06-10 14:32:35)

--- Frontend Bucket (event-booking-frontend-000000000000) ---
Total frontend files: 45

Latest frontend files:
  index.html (1024 bytes, 2026-06-10 14:15:00)
  static/js/main.abc123.js (256000 bytes, 2026-06-10 14:15:00)
  static/css/main.def456.css (48000 bytes, 2026-06-10 14:15:00)

Statistics:
  Tickets bucket size: 73728 bytes
  Frontend bucket size: 305024 bytes
```

**Use when:** Verifying ticket uploads, checking frontend deployment

---

## Complete Monitoring Workflow

### Test Booking Flow with Live Monitoring

1. **Start Floci & Deploy** (if not already running)
   ```bash
   podman-compose up -d
   bash scripts/deploy.sh
   ```

2. **Launch All Monitors**
   ```bash
   bash scripts/watch-all.sh
   ```

3. **In another terminal, start frontend**
   ```bash
   cd frontend
   npm start
   ```

4. **Open browser to** `http://localhost:3000`

5. **Login** with `demo@example.com / Demo@123456`

6. **Watch the data flow in real-time:**

   ```
   Step 1: User views events
   → watch-events.sh shows: Events loaded ✓
   → watch-logs.sh shows: "Events Lambda invoked"
   
   Step 2: User books event
   → watch-bookings.sh shows: New booking created (PENDING)
   → watch-logs.sh shows: "Booking created"
   → watch-sqs.sh shows: Message queued
   
   Step 3: Ticket Generator processes
   → watch-bookings.sh shows: Status PENDING → PROCESSING
   → watch-logs.sh shows: "Generating PDF..."
   → watch-sqs.sh shows: Message disappearing
   
   Step 4: Ticket uploaded
   → watch-bookings.sh shows: Status PROCESSING → CONFIRMED
   → watch-s3.sh shows: New PDF file uploaded
   → watch-logs.sh shows: "Ticket upload complete"
   
   Step 5: User views history
   → watch-bookings.sh shows: Final booking (CONFIRMED)
   → Download link ready!
   ```

---

## Tips & Tricks

### Color-Coded Status

In `watch-bookings.sh`:
- 🟡 **PENDING** (Yellow) — Waiting for processing
- 🔵 **PROCESSING** (Cyan) — Being processed
- 🟢 **CONFIRMED** (Green) — Complete & ready

### Stop a Monitor

Press `Ctrl+C` to stop any watch script.

### View Specific User's Bookings

```bash
# Query only one user's bookings
aws dynamodb query \
  --table-name Bookings \
  --key-condition-expression "userId = :userId" \
  --expression-attribute-values '{":userId":{"S":"user-001"}}' \
  --endpoint-url http://localhost:4566
```

### View Full Message Body in SQS

```bash
aws sqs receive-message \
  --queue-url http://localhost:4566/000000000000/us-east-1/BookingQueue \
  --endpoint-url http://localhost:4566 | jq '.Messages[0].Body | fromjson'
```

### Clear All Bookings (Test Reset)

```bash
# WARNING: Deletes all bookings!
aws dynamodb scan --table-name Bookings --endpoint-url http://localhost:4566 | \
  jq '.Items[].bookingId.S' | \
  xargs -I {} aws dynamodb delete-item \
    --table-name Bookings \
    --key '{"bookingId":{"S":"{}"},"userId":{"S":"user-001"}}' \
    --endpoint-url http://localhost:4566
```

---

## Troubleshooting

### Scripts won't run: "command not found"

Make them executable:
```bash
chmod +x scripts/watch-*.sh
```

### No output in watch-logs.sh

CloudWatch logs might be empty. Trigger a Lambda function:
1. Go to `http://localhost:3000`
2. View events → logs should appear

### SQS shows no messages

This is normal! Messages are processed immediately. To see them:
1. Book an event
2. Quickly open watch-sqs.sh before it's processed (< 2 seconds)

### S3 bucket not found

Verify deployment:
```bash
aws s3 ls --endpoint-url http://localhost:4566
```

Should show both `event-tickets-*` and `event-booking-frontend-*` buckets.

---

## Performance Impact

- **watch-logs.sh** — Minimal (streaming logs)
- **watch-bookings.sh** — Minimal (queries every 2 sec)
- **watch-events.sh** — Minimal (queries every 3 sec)
- **watch-sqs.sh** — Low (queries every 2 sec, small results)
- **watch-s3.sh** — Low (lists every 2 sec)

All scripts are read-only and don't impact application performance.

---

## Next Steps

- Run a complete test flow while watching all monitors
- Debug specific issues by checking logs + database state
- Verify data consistency across services
- Test failure scenarios (see `docs/TROUBLESHOOTING.md`)

Happy monitoring! 🚀
