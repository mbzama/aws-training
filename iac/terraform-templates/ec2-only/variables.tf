variable "aws_region" {
  description = "AWS region to deploy resources (us-east-1 only for subnet AZ filtering)"
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "ec2-practice"
}

variable "ec2_instance_type" {
  description = "EC2 instance type. Allowed: t2/t3/t3a micro|small|medium"
  type        = string
  default     = "t3.medium"

  validation {
    condition     = contains(["t2.micro", "t2.small", "t2.medium", "t3.micro", "t3.small", "t3.medium", "t3a.micro", "t3a.small", "t3a.medium"], var.ec2_instance_type)
    error_message = "Allowed values: t2/t3/t3a micro|small|medium only."
  }
}

variable "volume_size" {
  description = "Root EBS volume size in GB (8-30)"
  type        = number
  default     = 30

  validation {
    condition     = var.volume_size >= 8 && var.volume_size <= 30
    error_message = "Volume size must be between 8 and 30 GB."
  }
}
