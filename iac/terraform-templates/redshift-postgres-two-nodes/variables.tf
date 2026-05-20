variable "aws_region" {
  description = "AWS region to deploy resources (us-east-1 or us-west-2)"
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "redshift-two-nodes"
}

variable "node_type" {
  description = "Redshift node type"
  type        = string
  default     = "ra3.large"

  validation {
    condition     = contains(["ra3.large"], var.node_type)
    error_message = "Allowed values: ra3.large."
  }
}

variable "db_name" {
  description = "Redshift database name (lowercase only)"
  type        = string
  default     = "practicedb"
}

variable "db_username" {
  description = "Redshift master username (lowercase only). Cannot be 'admin', 'user', 'root', or 'postgres'."
  type        = string
  default     = "rsadmin"
}

variable "pg_db_name" {
  description = "PostgreSQL RDS database name"
  type        = string
  default     = "pgpracticedb"
}

variable "pg_username" {
  description = "PostgreSQL master username (cannot be 'postgres')"
  type        = string
  default     = "pgadmin"
}
