variable "node_type" {
  type        = string
  default     = "ra3.large"
  description = "Redshift node type."

  validation {
    condition     = contains(["ra3.large"], var.node_type)
    error_message = "Only ra3.large is permitted in sandbox environments."
  }
}

variable "db_name" {
  type        = string
  default     = "practicedb"
  description = "Name of the initial Redshift database (lowercase only)."

  validation {
    condition     = can(regex("^[a-z][a-z0-9_]{0,63}$", var.db_name))
    error_message = "db_name must start with a lowercase letter and contain only lowercase letters, digits, and underscores (max 64 chars)."
  }
}

variable "db_username" {
  type        = string
  default     = "rsadmin"
  description = "Redshift master username (lowercase only). Cannot be a reserved word such as admin, user, root, or postgres."

  validation {
    condition     = can(regex("^[a-z][a-z0-9_]{0,127}$", var.db_username))
    error_message = "db_username must start with a lowercase letter and contain only lowercase letters, digits, and underscores (max 128 chars)."
  }
}

variable "pg_db_name" {
  type        = string
  default     = "pgpracticedb"
  description = "Name of the initial PostgreSQL database."

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]{0,62}$", var.pg_db_name))
    error_message = "pg_db_name must start with a letter and contain only letters, digits, and underscores (max 63 chars)."
  }
}

variable "pg_username" {
  type        = string
  default     = "pgadmin"
  description = "PostgreSQL master username (cannot be 'postgres' - reserved by AWS)."

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9]{0,15}$", var.pg_username)) && var.pg_username != "postgres"
    error_message = "pg_username must start with a letter, contain only letters and digits, be at most 16 chars, and must not be 'postgres'."
  }
}

variable "stack_name" {
  type        = string
  default     = "redshift-postgres"
  description = "Logical name used to prefix all resource names (equivalent to CloudFormation stack name)."
}
