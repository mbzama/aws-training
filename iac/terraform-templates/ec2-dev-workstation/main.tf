terraform {
  required_version = ">= 1.5"
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

data "aws_ami" "ubuntu_22_arm64" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-arm64-server-*"]
  }

  filter {
    name   = "architecture"
    values = ["arm64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_security_group" "workstation" {
  name        = "${var.name_prefix}-sg"
  description = "Dev workstation access"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH for EC2 Instance Connect"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  ingress {
    description = "RDP"
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-sg" })
}

resource "aws_iam_role" "workstation" {
  name = "${var.name_prefix}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.workstation.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ec2_instance_connect" {
  role       = aws_iam_role.workstation.name
  policy_arn = "arn:aws:iam::aws:policy/EC2InstanceConnect"
}

resource "aws_iam_instance_profile" "workstation" {
  name = "${var.name_prefix}-profile"
  role = aws_iam_role.workstation.name
}

resource "aws_instance" "workstation" {
  ami                    = data.aws_ami.ubuntu_22_arm64.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.workstation.id]
  subnet_id              = var.subnet_id
  iam_instance_profile   = aws_iam_instance_profile.workstation.name

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size_gb
    delete_on_termination = true
    encrypted             = true
  }

  user_data = templatefile("${path.module}/user_data.sh", {
    rdp_password = var.rdp_password
    aws_region   = var.aws_region
  })

  metadata_options {
    http_tokens = "required" # IMDSv2
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-workstation" })
}

resource "aws_eip" "workstation" {
  count    = var.create_eip ? 1 : 0
  instance = aws_instance.workstation.id
  domain   = "vpc"

  tags = merge(var.tags, { Name = "${var.name_prefix}-eip" })
}
