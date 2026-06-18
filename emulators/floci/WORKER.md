# Event Booking Worker

Async worker that processes SQS messages and generates PDF tickets.

## What It Does

```
┌─────────────────┐
│  Flask Backend  │  1. Receives booking request
│  /book endpoint │     ├─ Saves to DynamoDB
│                 │     ├─ Queues message to SQS
│                 │     ├─ Publishes to SNS
│                 │     └─ Returns immediately (fast)
└────────┬────────┘
         │
    ┌────▼────────────────────┐
    │  SQS Queue (Async)       │
    │  BookingQueue            │
    │  ├─ Message 1            │
    │  ├─ Message 2            │
    │  └─ Message 3            │
    └────┬─────────────────────┘
         │
┌────────▼─────────────┐
│   Worker Service     │  2. Consumes messages
│                      │     ├─ Generates PDF
│  ├─ Polling SQS      │     ├─ Uploads to S3
│  ├─ Processing       │     └─ Updates DynamoDB
│  └─ PDF Generation   │
└──────────────────────┘
```

## How to Run

### Start the Worker

```bash
python worker.py
```

Output:
```
2026-06-14 14:30:00,123 - __main__ - INFO - Starting Event Booking Worker...
2026-06-14 14:30:00,456 - __main__ - INFO - Listening to SQS queue: BookingQueue
2026-06-14 14:30:05,789 - __main__ - INFO - Processing booking: BOOK-ABC123
2026-06-14 14:30:06,012 - __main__ - INFO - Ticket uploaded to S3: tickets/BOOK-ABC123.pdf
2026-06-14 14:30:06,234 - __main__ - INFO - Booking BOOK-ABC123 status updated to CONFIRMED
```

## In Another Terminal

Meanwhile, Flask and Frontend continue to work:

```bash
# Terminal 1: Flask Backend
python app.py

# Terminal 2: React Frontend
cd frontend && npm start

# Terminal 3: Worker (async processing)
python worker.py

# Terminal 4: Watch Infrastructure (optional)
bash scripts/watch-all.sh 2
```

## How It Works

1. **User Books Event** (Flask)
   - Request arrives at POST /book
   - Flask saves booking to DynamoDB
   - Flask queues message to SQS
   - Flask publishes to SNS
   - Flask returns response immediately (< 100ms)
   - ✅ User sees confirmation right away

2. **Worker Processes Message** (Async)
   - Worker polls SQS queue
   - Receives message: `{bookingId, eventName, quantity, totalPrice, userEmail}`
   - Generates PDF using ReportLab
   - Uploads PDF to S3
   - Updates booking status to CONFIRMED
   - Deletes message from queue
   - ✅ Ticket is ready in S3

3. **User Downloads Ticket**
   - User sees "Download Ticket" button
   - Clicks button
   - Frontend fetches from S3
   - Downloads to device

## Logs

Worker logs are saved to `worker.log`:

```bash
# View live logs
tail -f worker.log

# View errors only
grep ERROR worker.log
```

## Stopping the Worker

Press `Ctrl+C` to gracefully stop the worker:

```
^C
Worker stopping...
```

## Troubleshooting

### "No messages available"
- Normal! SQS is empty, waiting for bookings
- Go book an event in the UI
- Worker will process automatically

### "DynamoDB update failed"
- Check Floci is running: `podman ps | grep floci`
- Check credentials in aws_config

### "S3 upload failed"
- S3 bucket must exist: `aws s3api list-buckets --endpoint-url http://localhost:4566`
- Create if missing: `aws s3api create-bucket --bucket event-tickets-000000000000 --endpoint-url http://localhost:4566`

## Performance

- **Booking response time**: < 100ms (before worker kicks in)
- **PDF generation time**: ~500ms (happens async)
- **SQS polling interval**: 10 seconds (configurable)
- **Visibility timeout**: 60 seconds (time to process before re-queue)

## Architecture Benefits

✅ **Fast UI** - User gets instant confirmation  
✅ **Scalable** - Can run multiple workers  
✅ **Resilient** - Failed messages go to DLQ  
✅ **Observable** - All operations logged  
✅ **Production-ready** - Async pattern is standard  
