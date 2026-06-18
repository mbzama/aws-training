resource "aws_s3_bucket" "tickets" {
  bucket         = "event-tickets-${local.account_id}"
  force_destroy  = true

  tags = {
    Environment = local.environment
    Project     = local.project_name
  }
}
