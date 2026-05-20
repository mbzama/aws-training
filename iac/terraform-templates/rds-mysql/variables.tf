variable "aws_region" {
  description = "AWS region to deploy resources (us-east-1 or us-west-2)"
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "rds-mysql"
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

variable "db_instance_class" {
  description = "RDS instance class. Allowed: db.t3/t4g micro|small|medium"
  type        = string
  default     = "db.t3.micro"

  validation {
    condition     = contains(["db.t3.micro", "db.t3.small", "db.t3.medium", "db.t4g.micro", "db.t4g.small", "db.t4g.medium"], var.db_instance_class)
    error_message = "Allowed values: db.t3/t4g micro|small|medium only."
  }
}

variable "mysql_version" {
  description = "MySQL engine version"
  type        = string
  default     = "8.0"

  validation {
    condition     = contains(["8.0", "8.4", "5.7"], var.mysql_version)
    error_message = "Allowed values: 8.0, 8.4, 5.7."
  }
}

variable "db_name" {
  description = "Name of the initial MySQL database"
  type        = string
  default     = "practicedb"
}

variable "db_username" {
  description = "Master username (cannot be 'root')"
  type        = string
  default     = "admin"
}

variable "allocated_storage" {
  description = "Storage size in GB (20-50)"
  type        = number
  default     = 20

  validation {
    condition     = var.allocated_storage >= 20 && var.allocated_storage <= 50
    error_message = "Allocated storage must be between 20 and 50 GB."
  }
}
