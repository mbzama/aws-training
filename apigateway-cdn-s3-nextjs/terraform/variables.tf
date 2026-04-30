variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "app"
}

variable "domain_name" {
  description = "Custom domain name for the app (e.g. app.example.com)"
  type        = string
}

variable "certificate_domain" {
  description = "Primary domain of the ACM certificate to look up (e.g. example.com or *.example.com)"
  type        = string
}

variable "s3_bucket_versioning" {
  description = "Enable versioning for S3 bucket"
  type        = bool
  default     = true
}

variable "cloudfront_price_class" {
  description = "CloudFront price class"
  type        = string
  default     = "PriceClass_100"
}

variable "cf_default_ttl" {
  description = "CloudFront default TTL"
  type        = number
  default     = 3600
}

variable "cf_max_ttl" {
  description = "CloudFront max TTL"
  type        = number
  default     = 86400
}

variable "cf_min_ttl" {
  description = "CloudFront min TTL"
  type        = number
  default     = 0
}

variable "index_document" {
  description = "Index document for S3"
  type        = string
  default     = "index.html"
}

variable "error_document" {
  description = "Error document for S3"
  type        = string
  default     = "404.html"
}
