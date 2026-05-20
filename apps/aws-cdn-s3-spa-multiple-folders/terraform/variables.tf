variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "bucket_name" {
  description = "S3 bucket name for SPA assets (e.g. 123456789012-fed-module-demo)"
  type        = string
}

variable "alternate_domain" {
  description = "Custom domain name for the CloudFront distribution (e.g. myapp.example.com)"
  type        = string
}

variable "acm_certificate_arn" {
  description = "ARN of the ACM certificate for the alternate domain — must be in us-east-1 (e.g. arn:aws:acm:us-east-1:123456789012:certificate/...)"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g. production, staging)"
  type        = string
  default     = "production"
}
