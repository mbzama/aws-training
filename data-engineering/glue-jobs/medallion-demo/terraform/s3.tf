# ── S3 Bucket ─────────────────────────────────────────────────────────────────

resource "aws_s3_bucket" "medallion" {
  bucket = local.bucket_name
  tags   = local.common_tags
}

resource "aws_s3_bucket_versioning" "medallion" {
  bucket = aws_s3_bucket.medallion.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "medallion" {
  bucket = aws_s3_bucket.medallion.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "medallion" {
  bucket                  = aws_s3_bucket.medallion.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "medallion" {
  bucket = aws_s3_bucket.medallion.id

  # Transition old bronze raw files to cheaper storage after 90 days
  rule {
    id     = "bronze-ia-transition"
    status = "Enabled"
    filter { prefix = "bronze/" }
    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }
  }

  # Keep Spark event logs for 30 days then delete
  rule {
    id     = "spark-logs-expiry"
    status = "Enabled"
    filter { prefix = "spark-logs/" }
    expiration { days = 30 }
  }
}

# ── Glue scripts uploaded from local repo ─────────────────────────────────────

resource "aws_s3_object" "bronze_script" {
  bucket = aws_s3_bucket.medallion.id
  key    = "scripts/bronze_ingestion.py"
  source = "${path.module}/../glue_scripts/bronze_ingestion.py"
  etag   = filemd5("${path.module}/../glue_scripts/bronze_ingestion.py")
  tags   = local.common_tags
}

resource "aws_s3_object" "silver_script" {
  bucket = aws_s3_bucket.medallion.id
  key    = "scripts/silver_transformation.py"
  source = "${path.module}/../glue_scripts/silver_transformation.py"
  etag   = filemd5("${path.module}/../glue_scripts/silver_transformation.py")
  tags   = local.common_tags
}

resource "aws_s3_object" "gold_script" {
  bucket = aws_s3_bucket.medallion.id
  key    = "scripts/gold_aggregation.py"
  source = "${path.module}/../glue_scripts/gold_aggregation.py"
  etag   = filemd5("${path.module}/../glue_scripts/gold_aggregation.py")
  tags   = local.common_tags
}
