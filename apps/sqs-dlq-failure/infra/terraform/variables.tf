variable "environment" {
  type        = string
  default     = "dev"
  description = "Deployment environment — appended to all resource names"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod"
  }
}

variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region to deploy resources into"
}

# ── Queue Settings ────────────────────────────────────────────────────────────

variable "max_receive_count" {
  type        = number
  default     = 3
  description = <<-EOT
    Number of times SQS delivers a message before moving it to the DLQ.
    The worker intentionally does NOT delete invalid messages, so SQS
    increments ApproximateReceiveCount on each visibility timeout expiry.
    After this count is reached, SQS moves the message automatically.
  EOT

  validation {
    condition     = var.max_receive_count >= 1 && var.max_receive_count <= 1000
    error_message = "max_receive_count must be between 1 and 1000"
  }
}

variable "visibility_timeout_seconds" {
  type        = number
  default     = 30
  description = <<-EOT
    Seconds a received message is hidden from other consumers.
    Set this to at least the maximum time your worker needs to process one message.
    If the worker doesn't call DeleteMessage within this window, the message
    reappears and is counted as another receive attempt.
  EOT

  validation {
    condition     = var.visibility_timeout_seconds >= 0 && var.visibility_timeout_seconds <= 43200
    error_message = "visibility_timeout_seconds must be between 0 and 43200"
  }
}

variable "main_queue_retention_seconds" {
  type        = number
  default     = 86400 # 1 day
  description = "Message retention period for the main orders queue (seconds)"

  validation {
    condition     = contains([60, 86400, 345600, 604800, 1209600], var.main_queue_retention_seconds)
    error_message = "main_queue_retention_seconds must be one of: 60, 86400, 345600, 604800, 1209600"
  }
}

variable "dlq_retention_seconds" {
  type        = number
  default     = 1209600 # 14 days
  description = <<-EOT
    Message retention period for the DLQ (seconds).
    Keep high — failed messages should remain accessible for analysis and replay.
  EOT

  validation {
    condition     = contains([60, 86400, 345600, 604800, 1209600], var.dlq_retention_seconds)
    error_message = "dlq_retention_seconds must be one of: 60, 86400, 345600, 604800, 1209600"
  }
}

# ── Alarms ────────────────────────────────────────────────────────────────────

variable "alarm_sns_topic_arn" {
  type        = string
  default     = ""
  description = "ARN of an SNS topic to notify when alarms fire. Leave empty to skip notifications."
}

variable "queue_depth_alarm_threshold" {
  type        = number
  default     = 100
  description = "Number of visible messages in the main queue that triggers the depth alarm"
}

# ── Tags ──────────────────────────────────────────────────────────────────────

variable "common_tags" {
  type        = map(string)
  default     = {}
  description = "Tags applied to every resource. Merged with resource-specific tags."
}
