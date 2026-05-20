# Default VPC
data "aws_vpc" "default" {
  default = true
}

# Default subnets filtered to us-east-1a and us-east-1b
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

# Latest Amazon Linux 2023 AMI via SSM Parameter Store
data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# Security Group — port 22 required for EC2 Instance Connect
resource "aws_security_group" "ec2" {
  name        = "${var.name_prefix}-ec2-sg"
  description = "Allow SSH (22) for EC2 Instance Connect and HTTP (80)"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH for EC2 Instance Connect"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
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
    Name = "${var.name_prefix}-ec2-sg"
  }
}

# EC2 Instance — connect via EC2 Instance Connect, no key pair required
resource "aws_instance" "main" {
  ami                    = data.aws_ssm_parameter.al2023_ami.value
  instance_type          = var.ec2_instance_type
  subnet_id              = sort(data.aws_subnets.default.ids)[0]
  vpc_security_group_ids = [aws_security_group.ec2.id]
  tenancy                = "default"

  root_block_device {
    volume_size           = var.volume_size
    volume_type           = "gp3"
    delete_on_termination = true
  }

  user_data = <<-SCRIPT
    #!/bin/bash
    dnf update -y
    dnf install -y httpd
    systemctl enable httpd
    systemctl start httpd
    TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
      -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
    INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
      http://169.254.169.254/latest/meta-data/instance-id)
    AZ=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
      http://169.254.169.254/latest/meta-data/placement/availability-zone)
    cat > /var/www/html/index.html <<HTML
    <!DOCTYPE html>
    <html>
    <head><title>EC2 Practice</title></head>
    <body>
      <h1>EC2 Practice Instance</h1>
      <p><strong>Instance ID:</strong> $${INSTANCE_ID}</p>
      <p><strong>Availability Zone:</strong> $${AZ}</p>
    </body>
    </html>
    HTML
    SCRIPT

  tags = {
    Name = "${var.name_prefix}-ec2"
  }
}
