variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "dmsdb"
}

variable "db_username" {
  description = "Database master username"
  type        = string
  default     = "dmsuser"
}

variable "db_password" {
  description = "Database master password"
  type        = string
  sensitive   = true
}

variable "dms_username" {
  description = "DMS migration user"
  type        = string
  default     = "dms_migration_user"
}

variable "dms_password" {
  description = "DMS migration user password"
  type        = string
  sensitive   = true
}

variable "migration_type" {
  description = "DMS migration type: full-load, cdc, or full-load-and-cdc"
  type        = string
  default     = "full-load"
}
