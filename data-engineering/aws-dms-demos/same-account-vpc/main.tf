terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Security group — allow PostgreSQL from anywhere (learning only, restrict in prod)
resource "aws_security_group" "rds_sg" {
  name        = "dms-rds-sg"
  description = "Allow PostgreSQL access for DMS learning"
  vpc_id      = data.aws_vpc.default.id

  ingress {
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
}

resource "aws_db_subnet_group" "dms" {
  name       = "dms-subnet-group"
  subnet_ids = data.aws_subnets.default.ids
}

# Parameter group with logical replication enabled — required for DMS CDC
resource "aws_db_parameter_group" "postgres16" {
  name   = "dms-postgres16-params"
  family = "postgres16"

  parameter {
    name         = "rds.logical_replication"
    value        = "1"
    apply_method = "pending-reboot"
  }
}

resource "aws_db_instance" "source_rds" {
  identifier        = "source-rds"
  engine            = "postgres"
  engine_version    = "16"
  instance_class    = "db.t3.micro"
  allocated_storage = 20

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.dms.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  parameter_group_name   = aws_db_parameter_group.postgres16.name

  publicly_accessible     = true
  skip_final_snapshot     = true
  backup_retention_period = 1  # Required for DMS CDC
}

resource "aws_db_instance" "destination_rds" {
  identifier        = "destination-rds"
  engine            = "postgres"
  engine_version    = "16"
  instance_class    = "db.t3.micro"
  allocated_storage = 20

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.dms.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  publicly_accessible     = true
  skip_final_snapshot     = true
  backup_retention_period = 1
}
