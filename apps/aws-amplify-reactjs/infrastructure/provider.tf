# ============================================================
# Provider Configuration
# ============================================================
# ACM certificates used with AWS Amplify (and CloudFront) MUST be
# provisioned in us-east-1, regardless of where your other resources live.
# ============================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Primary provider — us-east-1 is mandatory for ACM + Amplify custom domains
provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = var.app_name
      Environment = "dev"
      ManagedBy   = "Terraform"
    }
  }
}
