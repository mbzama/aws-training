resource "aws_dynamodb_table" "events" {
  name           = "Events"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "eventId"

  attribute {
    name = "eventId"
    type = "S"
  }

  tags = {
    Environment = local.environment
    Project     = local.project_name
  }
}

resource "aws_dynamodb_table" "bookings" {
  name           = "Bookings"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "userId"
  range_key      = "bookingId"

  attribute {
    name = "userId"
    type = "S"
  }

  attribute {
    name = "bookingId"
    type = "S"
  }

  tags = {
    Environment = local.environment
    Project     = local.project_name
  }
}

# Seed Events table with sample data
resource "null_resource" "seed_events" {
  provisioner "local-exec" {
    command = "bash ${path.module}/seed-events.sh"
    environment = {
      AWS_ENDPOINT_URL        = "http://localhost:4566"
      AWS_ACCESS_KEY_ID       = "test"
      AWS_SECRET_ACCESS_KEY   = "test"
      AWS_DEFAULT_REGION      = "us-east-1"
    }
  }

  depends_on = [aws_dynamodb_table.events]
}
