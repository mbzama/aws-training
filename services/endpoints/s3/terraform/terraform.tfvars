# AWS region
aws_region = "us-east-1"

# Resource name prefix
stack_name = "s3-poc"

# EC2 instance type
instance_type = "t2.micro"

# Your existing EC2 key pair name (without .pem extension)
key_pair_name = "test2"

# VPC and subnet CIDRs (defaults used if omitted)
# vpc_cidr           = "10.0.0.0/16"
# public_subnet_cidr = "10.0.1.0/24"

# S3 bucket name prefix — account ID is appended automatically
bucket_name = "s3-vpc-endpoint-poc-2"

# Restrict access to your IP only (recommended)
# Find your IP at https://whatismyip.com
# Use ["0.0.0.0/0"] to allow all (not recommended)
allowed_cidr_blocks = ["0.0.0.0/0"]
