terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Uncomment and configure for remote state
  # backend "s3" {
  #   bucket = "your-terraform-state-bucket"
  #   key    = "api-gateway-lambda-authorizer/terraform.tfstate"
  #   region = "us-east-1"
  # }
}

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = local.common_tags
  }
}

# -------------------------------------------------------
# Random suffix for globally unique S3 bucket name
# -------------------------------------------------------
resource "random_string" "bucket_suffix" {
  length  = 8
  upper   = false
  special = false
}

# -------------------------------------------------------
# S3 bucket for Lambda deployment packages
# -------------------------------------------------------
resource "aws_s3_bucket" "lambda_artifacts" {
  bucket        = "api-bucket-demo-${random_string.bucket_suffix.result}"
  force_destroy = true

  tags = local.common_tags
}

resource "aws_s3_bucket_versioning" "lambda_artifacts" {
  bucket = aws_s3_bucket.lambda_artifacts.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "lambda_artifacts" {
  bucket = aws_s3_bucket.lambda_artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "lambda_artifacts" {
  bucket                  = aws_s3_bucket.lambda_artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

locals {
  environment = "staging"
  region      = "us-east-1"

  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = local.environment
    ManagedBy   = "terraform"
  })

  authorizer_function_name = "${var.project_name}-${local.environment}-authorizer"
  backend_function_name    = "${var.project_name}-${local.environment}-backend"
  api_name                 = "${var.project_name}-${local.environment}-api"
}

# -------------------------------------------------------
# Lambda: Authorizer
# -------------------------------------------------------
module "lambda_authorizer" {
  source = "./modules/lambda"

  function_name = local.authorizer_function_name
  description   = "JWT Lambda authorizer for API Gateway"
  handler       = "index.handler"
  runtime       = "nodejs20.x"
  architectures = ["arm64"]
  memory_size   = 256
  timeout       = 10

  s3_bucket = aws_s3_bucket.lambda_artifacts.id
  s3_key    = var.authorizer_s3_key

  environment_variables = {
    JWT_SECRET     = var.jwt_secret
    JWT_ALGORITHM  = var.jwt_algorithm
    JWT_ISSUER     = var.jwt_issuer
    JWT_AUDIENCE   = var.jwt_audience
    ALLOWED_SCOPES = var.allowed_scopes
  }

  log_retention_days = var.log_retention_days
  tags               = local.common_tags
}

# -------------------------------------------------------
# Lambda: Backend
# -------------------------------------------------------
module "lambda_backend" {
  source = "./modules/lambda"

  function_name = local.backend_function_name
  description   = "Backend Lambda handler for pet API"
  handler       = "index.handler"
  runtime       = "nodejs20.x"
  architectures = ["arm64"]
  memory_size   = 256
  timeout       = 10

  s3_bucket = aws_s3_bucket.lambda_artifacts.id
  s3_key    = var.backend_s3_key

  log_retention_days = var.log_retention_days
  tags               = local.common_tags
}

# -------------------------------------------------------
# API Gateway (HTTP API v2)
# -------------------------------------------------------
module "api_gateway" {
  source = "./modules/api_gateway"

  api_name    = local.api_name
  description = "Pet API protected by JWT Lambda authorizer"
  stage_name  = local.environment

  authorizer_invoke_arn    = module.lambda_authorizer.invoke_arn
  authorizer_function_name = module.lambda_authorizer.function_name
  authorizer_cache_ttl     = var.authorizer_cache_ttl

  backend_invoke_arn    = module.lambda_backend.invoke_arn
  backend_function_name = module.lambda_backend.function_name

  cors_allow_origins = var.cors_allow_origins
  tags               = local.common_tags
}
