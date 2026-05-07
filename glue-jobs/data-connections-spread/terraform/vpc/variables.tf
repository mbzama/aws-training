variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
  default     = "data-connections"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/24"
}

# /28 subnets carved from 10.0.0.0/24
# Each /28 = 16 IPs (11 usable after AWS reserves 5)
variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (/28 each)"
  type        = list(string)
  default     = ["10.0.0.0/28", "10.0.0.16/28"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (/28 each)"
  type        = list(string)
  default     = ["10.0.0.32/28", "10.0.0.48/28", "10.0.0.64/28"]
}

variable "availability_zones" {
  description = "List of availability zones (must have at least 3)"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnet internet access"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use a single NAT Gateway (cost-saving for non-prod)"
  type        = bool
  default     = true
}
