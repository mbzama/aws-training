output "orders_queue_url" {
  description = "URL of the main orders SQS queue"
  value       = aws_sqs_queue.orders_queue.url
}

output "orders_queue_arn" {
  description = "ARN of the main orders SQS queue"
  value       = aws_sqs_queue.orders_queue.arn
}

output "orders_queue_name" {
  description = "Name of the main orders SQS queue"
  value       = aws_sqs_queue.orders_queue.name
}

output "orders_dlq_url" {
  description = "URL of the Dead Letter Queue"
  value       = aws_sqs_queue.orders_dlq.url
}

output "orders_dlq_arn" {
  description = "ARN of the Dead Letter Queue"
  value       = aws_sqs_queue.orders_dlq.arn
}

output "orders_dlq_name" {
  description = "Name of the Dead Letter Queue"
  value       = aws_sqs_queue.orders_dlq.name
}

output "dlq_alarm_name" {
  description = "Name of the CloudWatch alarm that fires when messages hit the DLQ"
  value       = aws_cloudwatch_metric_alarm.dlq_messages_visible.alarm_name
}

# Convenience block — paste directly into .env.local
output "env_local_snippet" {
  description = "Environment variable values for .env.local"
  value       = <<-EOT
    # Add these to .env.local:
    SQS_QUEUE_URL=${aws_sqs_queue.orders_queue.url}
    SQS_DLQ_URL=${aws_sqs_queue.orders_dlq.url}
  EOT
}
