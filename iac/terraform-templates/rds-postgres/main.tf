# Default VPC — auto-detected (equivalent to Lambda custom resource in CloudFormation)
data "aws_vpc" "default" {
  default = true
}

# Default subnets in us-east-1a and us-east-1b
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  filter {
    name   = "defaultForAz"
    values = ["true"]
  }
  filter {
    name   = "availabilityZone"
    values = ["us-east-1a", "us-east-1b"]
  }
}

# Auto-generated master password stored in Secrets Manager
resource "random_password" "master" {
  length           = 32
  special          = true
  override_special = "!#$&*()-_=+[]{}<>?"
}

resource "aws_secretsmanager_secret" "rds_master" {
  name                    = "${var.name_prefix}-rds-master"
  description             = "PostgreSQL master password for ${var.name_prefix}"
  recovery_window_in_days = 0

  tags = {
    Name = "${var.name_prefix}-rds-master"
  }
}

resource "aws_secretsmanager_secret_version" "rds_master" {
  secret_id     = aws_secretsmanager_secret.rds_master.id
  secret_string = jsonencode({ password = random_password.master.result })
}

# Security Group — allow PostgreSQL port 5432
resource "aws_security_group" "rds" {
  name        = "${var.name_prefix}-rds-sg"
  description = "RDS PostgreSQL - allow port 5432 inbound"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "PostgreSQL from anywhere (restrict to your EC2 SG or IP in production)"
    from_port   = 5432
    to_port     = 5432
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
  description = "Subnet group for ${var.name_prefix} PostgreSQL RDS"
  subnet_ids  = data.aws_subnets.default.ids

  tags = {
    Name = "${var.name_prefix}-subnet-group"
  }
}

# RDS PostgreSQL Instance
resource "aws_db_instance" "postgres" {
  identifier     = "${var.name_prefix}-postgres"
  engine         = "postgres"
  engine_version = var.postgres_version
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
    Name = "${var.name_prefix}-postgres"
  }
}
