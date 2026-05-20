variable "aws_region" {
  description = "AWS region to deploy resources (us-east-1 or us-west-2)"
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "ec2-mysql-alb"
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

variable "db_instance_class" {
  description = "RDS instance class. Allowed: db.t3/t4g micro|small|medium"
  type        = string
  default     = "db.t3.medium"

  validation {
    condition     = contains(["db.t3.micro", "db.t3.small", "db.t3.medium", "db.t4g.micro", "db.t4g.small", "db.t4g.medium"], var.db_instance_class)
    error_message = "Allowed values: db.t3/t4g micro|small|medium only."
  }
}

variable "db_name" {
  description = "Name of the initial MySQL database"
  type        = string
  default     = "practicedb"
}

variable "db_username" {
  description = "RDS master username"
  type        = string
  default     = "admin"
}
