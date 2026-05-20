# ── Lambda IAM Role ────────────────────────────────────────────────────────────

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_ip_waiter" {
  name               = "${var.project_name}-lambda-ip-waiter-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
  tags               = local.common_tags
}

# Grants ENI create/delete in VPC + CloudWatch Logs writes
resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  role       = aws_iam_role.lambda_ip_waiter.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# ── Lambda Security Group ──────────────────────────────────────────────────────

resource "aws_security_group" "lambda_ip_waiter" {
  name        = "${var.project_name}-lambda-ip-waiter-sg"
  description = "Security group for the IP-exhaustion test Lambda"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = merge(local.common_tags, { Name = "${var.project_name}-lambda-ip-waiter-sg" })
}

# ── Lambda deployment package ──────────────────────────────────────────────────

data "archive_file" "lambda_ip_waiter" {
  type        = "zip"
  output_path = "${path.module}/lambda_ip_waiter.zip"

  source {
    filename = "index.py"
    content  = <<-PYTHON
      import os, time, socket

      def handler(event, context):
          my_ip       = socket.gethostbyname(socket.gethostname())
          subnet_id   = os.environ.get("SUBNET_ID", "unknown")
          subnet_name = os.environ.get("SUBNET_NAME", "unknown")
          print(f"[NETWORK] ip={my_ip} subnet_id={subnet_id} subnet_name={subnet_name}")
          wait = int(os.environ.get("WAIT_SECONDS", 300))
          time.sleep(wait)
          return {"statusCode": 200, "body": f"Slept {wait}s — ENI held for duration"}
    PYTHON
  }
}

# ── Lambda Function ────────────────────────────────────────────────────────────
# Pinned to private subnet 1, the same subnet as Glue network connection 1.
# Invoke it concurrently alongside a Glue run that uses connection 1 to consume
# IPs and trigger the "No free IPs" / subnet exhaustion error.

resource "aws_lambda_function" "ip_waiter" {
  function_name    = "${var.project_name}-ip-waiter"
  role             = aws_iam_role.lambda_ip_waiter.arn
  filename         = data.archive_file.lambda_ip_waiter.output_path
  source_code_hash = data.archive_file.lambda_ip_waiter.output_base64sha256
  handler          = "index.handler"
  runtime          = "python3.12"
  # 30s headroom beyond the sleep so the function can return before Lambda kills it
  timeout = var.lambda_wait_seconds + 30

  environment {
    variables = {
      WAIT_SECONDS = tostring(var.lambda_wait_seconds)
      SUBNET_ID    = aws_subnet.private[0].id
      SUBNET_NAME  = "${var.project_name}-private-1"
    }
  }

  vpc_config {
    subnet_ids         = [aws_subnet.private[0].id]
    security_group_ids = [aws_security_group.lambda_ip_waiter.id]
  }

  tags = merge(local.common_tags, { Name = "${var.project_name}-ip-waiter" })

  depends_on = [aws_iam_role_policy_attachment.lambda_vpc]
}
