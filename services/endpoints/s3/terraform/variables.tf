# ─────────────────────────────────────────────────────────────────────────────
# Variables
# ─────────────────────────────────────────────────────────────────────────────

variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region to deploy resources"
}

variable "stack_name" {
  type        = string
  default     = "s3-poc"
  description = "Prefix for all resource names"
}

variable "environment" {
  type        = string
  default     = "poc"
  description = "Environment tag (poc, dev, prod)"
}

variable "instance_type" {
  type        = string
  default     = "t2.micro"
  description = "EC2 instance type"

  validation {
    condition     = contains(["t2.micro", "t3.micro", "t3.small"], var.instance_type)
    error_message = "Instance type must be t2.micro, t3.micro, or t3.small."
  }
}

variable "key_pair_name" {
  type        = string
  description = "Name of existing EC2 key pair for SSH access"
}

variable "vpc_cidr" {
  type        = string
  default     = "10.0.0.0/16"
  description = "CIDR block for the VPC"
}

variable "public_subnet_cidr" {
  type        = string
  default     = "10.0.1.0/24"
  description = "CIDR block for the public subnet"
}

variable "bucket_name" {
  type        = string
  default     = "s3-vpc-endpoint-poc"
  description = "S3 bucket name prefix. Account ID is appended automatically."

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.bucket_name))
    error_message = "Bucket name must be lowercase letters, numbers, and hyphens only."
  }
}

variable "allowed_cidr_blocks" {
  type        = list(string)
  default     = ["0.0.0.0/0"]
  description = <<EOT
CIDR blocks allowed to access SSH (22) and Flask app (5000).
Restrict to your IP for better security: ["YOUR_IP/32"]
Find your IP at https://whatismyip.com
EOT
}
