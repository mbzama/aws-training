variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefix applied to every resource name"
  type        = string
  default     = "medallion-demo"
}

variable "bucket_suffix" {
  description = "Globally unique suffix appended to the S3 bucket name (e.g. your AWS account ID)"
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev | staging | prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging, or prod."
  }
}

variable "glue_version" {
  description = "AWS Glue version"
  type        = string
  default     = "4.0"
}

variable "worker_type" {
  description = "Glue worker type (G.1X = 1 DPU/worker)"
  type        = string
  default     = "G.1X"
}

variable "number_of_workers" {
  description = "Number of Glue workers; G.1X × 3 workers = 3 DPU max"
  type        = number
  default     = 3

  validation {
    condition     = var.number_of_workers >= 2
    error_message = "Minimum number_of_workers for a Spark ETL job is 2."
  }
}

variable "job_timeout_minutes" {
  description = "Max runtime per Glue job in minutes before forced termination"
  type        = number
  default     = 60
}
