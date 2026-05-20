data "aws_subnet" "private_2" {
  tags = {
    Name = "${local.name_prefix}-private-subnet-2"
  }
}
