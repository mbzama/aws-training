# Default VPC — auto-detected (equivalent to Lambda custom resource in CloudFormation)
data "aws_vpc" "default" {
  default = true
}

# All default subnets in the VPC
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  filter {
    name   = "defaultForAz"
    values = ["true"]
  }
}

# Auto-generated Redshift master password
resource "random_password" "redshift_master" {
  length           = 32
  special          = true
  override_special = "!#$&*()-_=+[]"
  min_upper        = 1
  min_lower        = 1
  min_numeric      = 1
  min_special      = 1
}

# Auto-generated PostgreSQL master password
resource "random_password" "pg_master" {
  length           = 32
  special          = true
  override_special = "!#$&*()-_=+[]{}<>?"
}

# Secrets Manager — Redshift credentials
resource "aws_secretsmanager_secret" "redshift_master" {
  name                    = "${var.name_prefix}-redshift-master"
  description             = "Redshift cluster master credentials"
  recovery_window_in_days = 0

  tags = {
    Name = "${var.name_prefix}-redshift-master"
  }
}

resource "aws_secretsmanager_secret_version" "redshift_master" {
  secret_id     = aws_secretsmanager_secret.redshift_master.id
  secret_string = jsonencode({ password = random_password.redshift_master.result })
}

# Secrets Manager — PostgreSQL credentials
resource "aws_secretsmanager_secret" "pg_master" {
  name                    = "${var.name_prefix}-postgres-master"
  description             = "PostgreSQL RDS master credentials"
  recovery_window_in_days = 0

  tags = {
    Name = "${var.name_prefix}-postgres-master"
  }
}

resource "aws_secretsmanager_secret_version" "pg_master" {
  secret_id     = aws_secretsmanager_secret.pg_master.id
  secret_string = jsonencode({ password = random_password.pg_master.result })
}

# Security Groups
resource "aws_security_group" "redshift" {
  name        = "${var.name_prefix}-redshift-sg"
  description = "Redshift - allow port 5439 inbound from within the VPC"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "Redshift from within VPC (JDBC/ODBC clients, SQL tools)"
    from_port   = 5439
    to_port     = 5439
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
    Name = "${var.name_prefix}-redshift-sg"
  }
}

resource "aws_security_group" "postgres" {
  name        = "${var.name_prefix}-postgres-sg"
  description = "PostgreSQL RDS - allow port 5432 from Redshift cluster only"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description     = "PostgreSQL from Redshift cluster"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.redshift.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-postgres-sg"
  }
}

# Redshift Subnet Group
resource "aws_redshift_subnet_group" "main" {
  name        = "${var.name_prefix}-redshift-subnet-group"
  description = "Subnet group for ${var.name_prefix} Redshift cluster"
  subnet_ids  = data.aws_subnets.default.ids

  tags = {
    Name = "${var.name_prefix}-redshift-subnet-group"
  }
}

# Redshift Single-Node Cluster
resource "aws_redshift_cluster" "main" {
  cluster_identifier = "${var.name_prefix}-cluster"
  cluster_type       = "single-node"
  number_of_nodes    = 1
  node_type          = var.node_type

  availability_zone = "${var.aws_region}a"

  database_name   = var.db_name
  master_username = var.db_username
  master_password = random_password.redshift_master.result

  vpc_security_group_ids    = [aws_security_group.redshift.id]
  cluster_subnet_group_name = aws_redshift_subnet_group.main.name

  publicly_accessible                 = true
  encrypted                           = true
  automated_snapshot_retention_period = 1
  allow_version_upgrade               = true
  preferred_maintenance_window        = "sun:05:00-sun:06:00"
  skip_final_snapshot                 = true

  tags = {
    Name = "${var.name_prefix}-cluster"
  }
}

# PostgreSQL RDS Subnet Group
resource "aws_db_subnet_group" "postgres" {
  name        = "${var.name_prefix}-postgres-subnet-group"
  description = "Subnet group for ${var.name_prefix} PostgreSQL RDS"
  subnet_ids  = data.aws_subnets.default.ids

  tags = {
    Name = "${var.name_prefix}-postgres-subnet-group"
  }
}

# PostgreSQL RDS — connected to Redshift via security group on port 5432
resource "aws_db_instance" "postgres" {
  identifier     = "${var.name_prefix}-postgres"
  engine         = "postgres"
  engine_version = "17.2"
  instance_class = "db.t3.medium"

  db_name  = var.pg_db_name
  username = var.pg_username
  password = random_password.pg_master.result

  allocated_storage     = 20
  max_allocated_storage = 50
  storage_type          = "gp3"
  storage_encrypted     = false

  db_subnet_group_name   = aws_db_subnet_group.postgres.name
  vpc_security_group_ids = [aws_security_group.postgres.id]
  publicly_accessible    = false
  multi_az               = false

  backup_retention_period = 0
  deletion_protection     = false
  skip_final_snapshot     = true

  tags = {
    Name = "${var.name_prefix}-postgres"
  }
}
