# Real-Time Infrastructure Viewer Scripts

Monitor your Floci infrastructure in real-time as you make bookings!

## Usage

### Watch Everything (Recommended for Demo)
```bash
bash scripts/watch-all.sh       # Refreshes every 5 seconds
bash scripts/watch-all.sh 2     # Refreshes every 2 seconds (faster)
bash scripts/watch-all.sh 10    # Refreshes every 10 seconds (slower)
```

### Watch Individual Services
```bash
# DynamoDB Tables (Events & Bookings)
bash scripts/watch-dynamodb.sh      # Default: 3 seconds
bash scripts/watch-dynamodb.sh 1    # Faster: 1 second

# S3 Buckets (Tickets)
bash scripts/watch-s3.sh            # Default: 3 seconds
bash scripts/watch-s3.sh 2          # Custom: 2 seconds

# SQS Queues (Messages)
bash scripts/watch-sqs.sh           # Default: 3 seconds
bash scripts/watch-sqs.sh 5         # Slower: 5 seconds

# SNS Topics (Notifications)
bash scripts/watch-sns.sh           # Default: 3 seconds
```

## Demo Workflow

**Terminal 1: Start the watcher**
```bash
bash scripts/watch-all.sh 2
```

**Terminal 2: Open browser and book events**
```
1. Open http://localhost:3000
2. Login: demo@example.com / Demo@123456
3. Click "Browse Events"
4. Click "Book Now" on an event
5. Confirm booking
```

**Watch Terminal 1 to see:**
- ✅ Booking appears in DynamoDB Bookings table
- ✅ Ticket PDF generated in S3
- ✅ Message queued in SQS
- ✅ Updates in real-time as you refresh!

## What You'll See

### DynamoDB
```
Events: 4 (seeded)
Bookings: X (grows as you book)
```

### S3
```
Tickets generated: X (grows as you book)
```

### SQS
```
Booking Queue: X messages pending
Dead Letter Queue: X failed messages
```

### SNS
```
Topics: 1 (BookingNotifications)
Subscriptions: 0 (but messages are published)
```

## Demo Script Suggestion

```bash
# Terminal 1: Watch infrastructure
bash scripts/watch-all.sh 3

# Terminal 2: Make bookings (in browser)
# Each time you book, watch the numbers update in Terminal 1!
```

This is perfect for demonstrations and development!
