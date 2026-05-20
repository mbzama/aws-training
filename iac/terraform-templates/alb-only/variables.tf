variable "aws_region" {
  description = "AWS region to deploy resources (us-east-1 or us-west-2)"
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "alb-practice"
}

variable "vpc_id" {
  description = "VPC ID. Leave empty to use the default VPC."
  type        = string
  default     = ""
}

variable "subnet_ids" {
  description = "List of subnet IDs (at least 2 in different AZs). Leave empty to use default VPC subnets."
  type        = list(string)
  default     = []
}

variable "alb_scheme" {
  description = "ALB scheme: internet-facing or internal"
  type        = string
  default     = "internet-facing"

  validation {
    condition     = contains(["internet-facing", "internal"], var.alb_scheme)
    error_message = "Allowed values: internet-facing, internal."
  }
}

variable "enable_https" {
  description = "Enable HTTPS listener on port 443. Requires certificate_arn."
  type        = bool
  default     = false
}

variable "certificate_arn" {
  description = "ACM Certificate ARN for HTTPS. Required if enable_https is true."
  type        = string
  default     = ""
}

variable "target_port" {
  description = "Port your backend instances listen on"
  type        = number
  default     = 80
}

variable "health_check_path" {
  description = "Path used by ALB to health-check targets"
  type        = string
  default     = "/"
}
