# ── Available AZs (dynamic, works in any region) ──────────────────────────────

data "aws_availability_zones" "available" {
  state = "available"
}

# ── VPC ────────────────────────────────────────────────────────────────────────

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, { Name = "${var.project_name}-vpc" })
}

# ── Subnets ────────────────────────────────────────────────────────────────────

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-public-${count.index + 1}"
    Tier = "public"
  })
}

resource "aws_subnet" "private" {
  count             = 3
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-private-${count.index + 1}"
    Tier = "private"
  })
}

# ── Internet Gateway ──────────────────────────────────────────────────────────

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, { Name = "${var.project_name}-igw" })
}

# ── NAT Gateway (single, in public-1) ────────────────────────────────────────

resource "aws_eip" "nat" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.main]

  tags = merge(local.common_tags, { Name = "${var.project_name}-nat-eip" })
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  depends_on    = [aws_internet_gateway.main]

  tags = merge(local.common_tags, { Name = "${var.project_name}-nat-gw" })
}

# ── Route Tables ──────────────────────────────────────────────────────────────

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(local.common_tags, { Name = "${var.project_name}-public-rt" })
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = merge(local.common_tags, { Name = "${var.project_name}-private-rt" })
}

# ── Route Table Associations ──────────────────────────────────────────────────

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = 3
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# ── S3 VPC Gateway Endpoint ───────────────────────────────────────────────────
# Routes S3 traffic directly from private subnets without going through NAT,
# which is required for Glue jobs to reach S3 at no extra data-transfer cost.

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]

  tags = merge(local.common_tags, { Name = "${var.project_name}-s3-endpoint" })
}

# ── Glue Security Group ───────────────────────────────────────────────────────

resource "aws_security_group" "glue" {
  name        = "${var.project_name}-glue-sg"
  description = "Security group for Glue ETL jobs"
  vpc_id      = aws_vpc.main.id

  tags = merge(local.common_tags, { Name = "${var.project_name}-glue-sg" })
}

# Glue requires a self-referencing inbound rule when running inside a VPC —
# worker nodes communicate with each other through this rule.
resource "aws_security_group_rule" "glue_self_inbound" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  self              = true
  security_group_id = aws_security_group.glue.id
  description       = "Self-referencing rule required by AWS Glue"
}

resource "aws_security_group_rule" "glue_all_outbound" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.glue.id
  description       = "Allow all outbound (S3 via endpoint, AWS APIs via NAT)"
}

# ── Glue Network Connections (one per private subnet) ────────────────────────
# Three connections map 1:1 to the three private subnets.
# Bronze lists all three so Glue can distribute parallel run workers across
# subnets, preventing IP exhaustion in any single /24 under high parallelism.
# Silver and Gold each use a dedicated single connection.

resource "aws_glue_connection" "network" {
  count           = 3
  name            = "${var.project_name}-network-connection-${count.index + 1}"
  description     = "Places Glue workers into private subnet ${count.index + 1} (${aws_subnet.private[count.index].availability_zone})"
  connection_type = "NETWORK"

  physical_connection_requirements {
    availability_zone      = aws_subnet.private[count.index].availability_zone
    security_group_id_list = [aws_security_group.glue.id]
    subnet_id              = aws_subnet.private[count.index].id
  }

  tags = merge(local.common_tags, {
    Subnet = aws_subnet.private[count.index].id
  })
}
