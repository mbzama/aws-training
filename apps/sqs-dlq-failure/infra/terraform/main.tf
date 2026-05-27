# ─────────────────────────────────────────────────────────────────────────────
# SQS Orders Queue + Dead Letter Queue (DLQ)
# sqs-dlq-failure demo
# ─────────────────────────────────────────────────────────────────────────────

# ── 1. Dead Letter Queue ──────────────────────────────────────────────────────
# Must exist first so we can reference its ARN in the main queue's redrive policy.
resource "aws_sqs_queue" "orders_dlq" {
  name = "orders-dlq-${var.environment}"

  # Keep failed messages for 14 days so engineers can inspect and replay them
  message_retention_seconds = var.dlq_retention_seconds

  tags = merge(var.common_tags, {
    Name      = "orders-dlq-${var.environment}"
    QueueType = "dlq"
  })
}

# ── 2. Main Orders Queue ──────────────────────────────────────────────────────
resource "aws_sqs_queue" "orders_queue" {
  name = "orders-queue-${var.environment}"

  # How long (seconds) a received message is hidden from other consumers.
  # If the worker doesn't call DeleteMessage within this window, the message
  # becomes visible again and counts as another receive attempt.
  visibility_timeout_seconds = var.visibility_timeout_seconds

  # Short retention for the main queue — messages should process quickly
  message_retention_seconds = var.main_queue_retention_seconds

  # Long polling: workers wait up to 20s for messages instead of
  # immediately returning empty responses. Reduces API call count and cost.
  receive_wait_time_seconds = 20

  # Redrive Policy — the core DLQ mechanism.
  # After max_receive_count failed attempts, SQS automatically moves the
  # message to the DLQ. No application code is required for this.
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.orders_dlq.arn
    maxReceiveCount     = var.max_receive_count
  })

  tags = merge(var.common_tags, {
    Name      = "orders-queue-${var.environment}"
    QueueType = "main"
  })
}

# ── 3. DLQ Redrive Allow Policy ───────────────────────────────────────────────
# Explicitly permits the main queue to use this DLQ as its dead-letter target.
# Required since AWS tightened cross-account DLQ permissions (2021).
resource "aws_sqs_queue_redrive_allow_policy" "orders_dlq_allow" {
  queue_url = aws_sqs_queue.orders_dlq.id

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.orders_queue.arn]
  })
}

# ── 4. CloudWatch Alarms ──────────────────────────────────────────────────────

# Alert as soon as any message lands in the DLQ
resource "aws_cloudwatch_metric_alarm" "dlq_messages_visible" {
  alarm_name          = "orders-dlq-messages-visible-${var.environment}"
  alarm_description   = "Messages are landing in the DLQ — order processing failures detected. Check failure-processor logs."
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = aws_sqs_queue.orders_dlq.name
  }

  alarm_actions = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []
  ok_actions    = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []

  tags = var.common_tags
}

# Alert when the main queue backs up (workers may be down)
resource "aws_cloudwatch_metric_alarm" "main_queue_depth" {
  alarm_name          = "orders-queue-depth-${var.environment}"
  alarm_description   = "Main orders queue depth is high — workers may be unhealthy or under-provisioned."
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 2
  threshold           = var.queue_depth_alarm_threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = aws_sqs_queue.orders_queue.name
  }

  alarm_actions = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []

  tags = var.common_tags
}
