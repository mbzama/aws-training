# Default VPC (used when vpc_id variable is empty)
data "aws_vpc" "default" {
  count   = var.vpc_id == "" ? 1 : 0
  default = true
}

# Default subnets (used when subnet_ids variable is empty)
data "aws_subnets" "default" {
  count = var.subnet_ids == [] || length(var.subnet_ids) == 0 ? 1 : 0

  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }
  filter {
    name   = "defaultForAz"
    values = ["true"]
  }
}

locals {
  vpc_id     = var.vpc_id != "" ? var.vpc_id : data.aws_vpc.default[0].id
  subnet_ids = length(var.subnet_ids) > 0 ? var.subnet_ids : data.aws_subnets.default[0].ids
}

# Auto-generated master password stored in Secrets Manager
resource "random_password" "master" {
  length           = 32
  special          = true
  override_special = "!#$&*()-_=+[]{}<>?"
}

resource "aws_secretsmanager_secret" "rds_master" {
  name                    = "${var.name_prefix}-rds-master"
  description             = "MySQL master password for ${var.name_prefix}"
  recovery_window_in_days = 0

  tags = {
    Name = "${var.name_prefix}-rds-master"
  }
}

resource "aws_secretsmanager_secret_version" "rds_master" {
  secret_id     = aws_secretsmanager_secret.rds_master.id
  secret_string = jsonencode({ password = random_password.master.result })
}

# Security Group — allow MySQL port 3306
resource "aws_security_group" "rds" {
  name        = "${var.name_prefix}-rds-sg"
  description = "RDS MySQL - allow port 3306 inbound"
  vpc_id      = local.vpc_id

  ingress {
    description = "MySQL from anywhere (restrict to your EC2 SG or IP in production)"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-rds-sg"
  }
}

# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name        = "${var.name_prefix}-subnet-group"
  description = "Subnet group for ${var.name_prefix} MySQL RDS"
  subnet_ids  = local.subnet_ids

  tags = {
    Name = "${var.name_prefix}-subnet-group"
  }
}

# RDS MySQL Instance
resource "aws_db_instance" "mysql" {
  identifier     = "${var.name_prefix}-mysql"
  engine         = "mysql"
  engine_version = var.mysql_version
  instance_class = var.db_instance_class

  db_name  = var.db_name
  username = var.db_username
  password = random_password.master.result

  allocated_storage     = var.allocated_storage
  max_allocated_storage = 50
  storage_type          = "gp3"
  storage_encrypted     = false

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = true
  multi_az               = false

  backup_retention_period = 0
  deletion_protection     = false
  skip_final_snapshot     = true

  tags = {
    Name = "${var.name_prefix}-mysql"
  }
}
