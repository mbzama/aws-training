variable "aws_region" {
  description = "AWS region to deploy resources (us-east-1 only)"
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "rds-postgres"
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

variable "postgres_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "16.3"

  validation {
    condition     = contains(["16.3", "15.7", "14.12", "13.15"], var.postgres_version)
    error_message = "Allowed values: 16.3, 15.7, 14.12, 13.15."
  }
}

variable "db_name" {
  description = "Name of the initial PostgreSQL database"
  type        = string
  default     = "practicedb"
}

variable "db_username" {
  description = "Master username (cannot be 'postgres')"
  type        = string
  default     = "pgadmin"
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
