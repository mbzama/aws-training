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
  description = "Number of Glue workers; G.1X × 2 workers = 2 DPU (fits within 4 DPU total limit)"
  type        = number
  default     = 2

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

# ── Networking ────────────────────────────────────────────────────────────────

variable "vpc_cidr" {
  description = "CIDR block for the project VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the two public subnets (must be within vpc_cidr)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]

  validation {
    condition     = length(var.public_subnet_cidrs) == 2
    error_message = "Exactly 2 public subnet CIDRs are required."
  }
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for the three private subnets (must be within vpc_cidr)"
  type        = list(string)
  default     = ["10.0.10.0/28", "10.0.11.0/28", "10.0.12.0/28"]

  validation {
    condition     = length(var.private_subnet_cidrs) == 3
    error_message = "Exactly 3 private subnet CIDRs are required."
  }
}
