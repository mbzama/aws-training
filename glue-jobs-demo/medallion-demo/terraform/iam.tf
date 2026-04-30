# ── Glue IAM Role ─────────────────────────────────────────────────────────────

data "aws_iam_policy_document" "glue_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["glue.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "glue" {
  name               = "${var.project_name}-glue-role"
  assume_role_policy = data.aws_iam_policy_document.glue_assume_role.json
  tags               = local.common_tags
}

# AWS managed policy: CloudWatch logs, Glue catalog, EC2 networking
resource "aws_iam_role_policy_attachment" "glue_service" {
  role       = aws_iam_role.glue.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# ── S3 access scoped to the medallion bucket ──────────────────────────────────

data "aws_iam_policy_document" "glue_s3" {
  statement {
    sid    = "BucketList"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]
    resources = [aws_s3_bucket.medallion.arn]
  }

  statement {
    sid    = "ObjectReadWrite"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = ["${aws_s3_bucket.medallion.arn}/*"]
  }
}

resource "aws_iam_policy" "glue_s3" {
  name   = "${var.project_name}-glue-s3-policy"
  policy = data.aws_iam_policy_document.glue_s3.json
  tags   = local.common_tags
}

resource "aws_iam_role_policy_attachment" "glue_s3" {
  role       = aws_iam_role.glue.name
  policy_arn = aws_iam_policy.glue_s3.arn
}
