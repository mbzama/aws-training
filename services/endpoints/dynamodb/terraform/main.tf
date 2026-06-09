# ─────────────────────────────────────────────────────────────────────────────
# DynamoDB VPC Gateway Endpoint POC — Terraform
# Creates: VPC, Subnets, IGW, EC2, DynamoDB Table, IAM Role, VPC Gateway Endpoint
# Flask app installed and started automatically via user_data
# No Docker needed — launch and open the URL
# ─────────────────────────────────────────────────────────────────────────────

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

# ── Data sources ──────────────────────────────────────────────────────────────

# Latest Amazon Linux 2023 AMI
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-kernel-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Current AWS account ID
data "aws_caller_identity" "current" {}

# ── VPC ───────────────────────────────────────────────────────────────────────
resource "aws_vpc" "poc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "${var.stack_name}-vpc"
    Project     = "DynamoDB-Gateway-Endpoint-POC"
    Environment = var.environment
  }
}

# ── INTERNET GATEWAY ──────────────────────────────────────────────────────────
resource "aws_internet_gateway" "poc" {
  vpc_id = aws_vpc.poc.id

  tags = {
    Name    = "${var.stack_name}-igw"
    Project = "DynamoDB-Gateway-Endpoint-POC"
  }
}

# ── PUBLIC SUBNET ─────────────────────────────────────────────────────────────
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.poc.id
  cidr_block              = var.public_subnet_cidr
  map_public_ip_on_launch = true

  tags = {
    Name    = "${var.stack_name}-public-subnet"
    Project = "DynamoDB-Gateway-Endpoint-POC"
  }
}

# ── ROUTE TABLE ───────────────────────────────────────────────────────────────
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.poc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.poc.id
  }

  tags = {
    Name    = "${var.stack_name}-public-rt"
    Project = "DynamoDB-Gateway-Endpoint-POC"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ── DYNAMODB TABLE ────────────────────────────────────────────────────────────
resource "aws_dynamodb_table" "poc" {
  name         = var.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = {
    Project     = "DynamoDB-Gateway-Endpoint-POC"
    CreatedBy   = "Terraform"
    Environment = var.environment
  }
}

# ── IAM ROLE FOR EC2 ──────────────────────────────────────────────────────────
resource "aws_iam_role" "ec2_dynamodb" {
  name = "${var.stack_name}-ec2-dynamodb-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Project = "DynamoDB-Gateway-Endpoint-POC"
  }
}

resource "aws_iam_role_policy" "ec2_dynamodb_access" {
  name = "DynamoDBTableAccess"
  role = aws_iam_role.ec2_dynamodb.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowDynamoDBTableOperations"
      Effect = "Allow"
      Action = [
        "dynamodb:PutItem",
        "dynamodb:GetItem",
        "dynamodb:DeleteItem",
        "dynamodb:Scan",
        "dynamodb:UpdateItem",
        "dynamodb:BatchWriteItem",
        "dynamodb:DescribeTable"
      ]
      Resource = aws_dynamodb_table.poc.arn
    }]
  })
}

# SSM access for session manager (optional SSH alternative)
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2_dynamodb.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_dynamodb" {
  name = "${var.stack_name}-instance-profile"
  role = aws_iam_role.ec2_dynamodb.name
}

# ── SECURITY GROUP ────────────────────────────────────────────────────────────
resource "aws_security_group" "poc" {
  name        = "${var.stack_name}-sg"
  description = "SSH and Flask app access"
  vpc_id      = aws_vpc.poc.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  ingress {
    description = "Flask app"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Project = "DynamoDB-Gateway-Endpoint-POC"
    Name    = "${var.stack_name}-sg"
  }
}

# ── EC2 INSTANCE ──────────────────────────────────────────────────────────────
resource "aws_instance" "poc" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  key_name                    = var.key_pair_name
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.poc.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_dynamodb.name
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/userdata.sh", {
    table_name = aws_dynamodb_table.poc.id
    aws_region = var.aws_region
  })

  user_data_replace_on_change = true

  tags = {
    Name        = "${var.stack_name}-ec2"
    Project     = "DynamoDB-Gateway-Endpoint-POC"
    Environment = var.environment
  }

  depends_on = [aws_dynamodb_table.poc, aws_internet_gateway.poc]
}

# ── VPC GATEWAY ENDPOINT — DynamoDB ──────────────────────────────────────────
resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = aws_vpc.poc.id
  service_name      = "com.amazonaws.${var.aws_region}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.public.id]

  # Endpoint policy: restrict access to our specific table only
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = "*"
      Action    = "dynamodb:*"
      Resource  = aws_dynamodb_table.poc.arn
    }]
  })

  tags = {
    Name    = "${var.stack_name}-dynamodb-endpoint"
    Project = "DynamoDB-Gateway-Endpoint-POC"
  }
}
