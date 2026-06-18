resource "aws_sqs_queue" "booking_dlq" {
  name                       = "BookingQueueDLQ"
  message_retention_seconds  = 1209600

  tags = {
    Environment = local.environment
    Project     = local.project_name
  }
}

resource "aws_sqs_queue" "booking_queue" {
  name                        = "BookingQueue"
  visibility_timeout_seconds  = 300
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.booking_dlq.arn
    maxReceiveCount     = 3
  })

  tags = {
    Environment = local.environment
    Project     = local.project_name
  }
}

resource "aws_sns_topic" "booking_notifications" {
  name = "BookingNotifications"

  tags = {
    Environment = local.environment
    Project     = local.project_name
  }
}

resource "aws_sns_topic_subscription" "booking_notifications_email" {
  topic_arn = aws_sns_topic.booking_notifications.arn
  protocol  = "email"
  endpoint  = var.notification_email
}
