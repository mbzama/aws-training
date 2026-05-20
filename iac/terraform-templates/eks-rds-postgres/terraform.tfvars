# AWS Configuration
aws_region = "us-east-1"

# Cluster Configuration
cluster_name    = "hrms-cluster"
cluster_version = "1.31"

# Node Group Configuration
node_group_name    = "hrms-ng-2"
node_instance_type = "t3.medium"
node_desired_size  = 1
node_min_size      = 1
node_max_size      = 1
node_disk_size     = 20

# Tags
environment = "learning"

# VPC Configuration
vpc_cidr = "10.0.0.0/16"

# RDS Configuration
db_engine                  = "postgres"
db_engine_version          = "16.6"
db_instance_class          = "db.t3.micro"
db_name                    = "hrmsdb"
db_username                = "hrmsadmin"
db_allocated_storage       = 20
db_storage_type            = "gp2"
db_multi_az                = false
db_publicly_accessible     = true
db_backup_retention_period = 7
db_skip_final_snapshot     = true
db_deletion_protection     = false
