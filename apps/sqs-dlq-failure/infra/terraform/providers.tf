terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
  }

  # ── Remote State (optional — uncomment for team use) ─────────────────────
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "sqs-dlq-failure/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-lock"
  # }
}

provider "aws" {
  region = var.aws_region

  # ── LocalStack override (for local development) ───────────────────────────
  # Uncomment this block when running against LocalStack instead of real AWS.
  # dynamic "endpoints" {
  #   for_each = var.localstack_endpoint != "" ? [1] : []
  #   content {
  #     sqs        = var.localstack_endpoint
  #     cloudwatch = var.localstack_endpoint
  #   }
  # }

  default_tags {
    tags = {
      Project     = "sqs-dlq-failure"
      ManagedBy   = "terraform"
      Environment = var.environment
    }
  }
}
