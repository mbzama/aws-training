terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Uncomment to use remote state
  # backend "s3" {
  #   bucket         = "terraform-state-zamait"
  #   key            = "app/dev/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-locks"
  # }
}

provider "aws" {
  region = var.aws_region
}

# Explicit us-east-1 provider — ACM certs for CloudFront and API Gateway must live here
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

# Data source for current AWS account ID
data "aws_caller_identity" "current" {}

locals {
  bucket_name = "${var.project_name}-${var.environment}-${var.aws_region}-${data.aws_caller_identity.current.account_id}"
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
    CreatedAt   = timestamp()
  }
}
