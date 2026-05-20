terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    postgresql = {
      source  = "cyrilgdn/postgresql"
      version = "~> 1.22"
    }
  }
}

provider "postgresql" {
  host            = aws_rds_cluster.source.endpoint
  port            = 5432
  database        = var.db_name
  username        = var.db_username
  password        = var.db_password
  sslmode         = "require"
  superuser       = false  # RDS master user is not a true superuser
  connect_timeout = 15
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

# -------------------------------------------------------
# Source — Aurora PostgreSQL 14
# -------------------------------------------------------

resource "aws_rds_cluster_parameter_group" "source" {
  name   = "dms-aurora-pg14-params"
  family = "aurora-postgresql14"

  parameter {
    name         = "rds.logical_replication"
    value        = "1"
    apply_method = "pending-reboot"
  }
}

resource "aws_rds_cluster" "source" {
  cluster_identifier      = "source-aurora-cluster"
  engine                  = "aurora-postgresql"
  engine_version          = "14.12"
  database_name           = var.db_name
  master_username         = var.db_username
  master_password         = var.db_password

  db_subnet_group_name            = aws_db_subnet_group.dms.name
  vpc_security_group_ids          = [aws_security_group.rds_sg.id]
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.source.name

  enabled_cloudwatch_logs_exports = ["postgresql"]

  skip_final_snapshot     = true
  backup_retention_period = 1  # Required for DMS CDC
}

resource "aws_rds_cluster_instance" "source" {
  identifier         = "source-rds"
  cluster_identifier = aws_rds_cluster.source.id
  instance_class     = "db.t3.medium"
  engine             = aws_rds_cluster.source.engine
  engine_version     = aws_rds_cluster.source.engine_version

  publicly_accessible = true
}

# -------------------------------------------------------
# Destination — Aurora PostgreSQL 15
# -------------------------------------------------------

resource "aws_rds_cluster_parameter_group" "destination" {
  name   = "dms-aurora-pg15-params"
  family = "aurora-postgresql15"
}

resource "aws_rds_cluster" "destination" {
  cluster_identifier = "destination-aurora-cluster"
  engine             = "aurora-postgresql"
  engine_version     = "15.6"
  database_name      = var.db_name
  master_username    = var.db_username
  master_password    = var.db_password

  db_subnet_group_name            = aws_db_subnet_group.dms.name
  vpc_security_group_ids          = [aws_security_group.rds_sg.id]
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.destination.name

  enabled_cloudwatch_logs_exports = ["postgresql"]

  skip_final_snapshot     = true
  backup_retention_period = 1
}

resource "aws_rds_cluster_instance" "destination" {
  identifier         = "destination-rds"
  cluster_identifier = aws_rds_cluster.destination.id
  instance_class     = "db.t3.medium"
  engine             = aws_rds_cluster.destination.engine
  engine_version     = aws_rds_cluster.destination.engine_version

  publicly_accessible = true
}
