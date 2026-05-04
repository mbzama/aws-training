# ── Shared job defaults ───────────────────────────────────────────────────────

locals {
  glue_default_args = {
    "--job-language"                     = "python"
    "--job-bookmark-option"              = "job-bookmark-disable"
    "--enable-metrics"                   = "true"
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-spark-ui"                  = "true"
    "--spark-event-logs-path"            = "s3://${aws_s3_bucket.medallion.id}/spark-logs/"
    "--S3_BUCKET"                        = aws_s3_bucket.medallion.id
  }
}

# ── Bronze: raw data ingestion ────────────────────────────────────────────────

resource "aws_glue_job" "bronze" {
  name         = "${var.project_name}-bronze-ingestion"
  description  = "Generates 1,000 sample e-commerce records and writes raw JSON to S3 bronze layer"
  role_arn     = aws_iam_role.glue.arn
  glue_version = var.glue_version
  # All three private-subnet connections listed so Glue can spread workers
  # across subnets when many parallel runs are active, avoiding IP exhaustion.
  connections = [
    aws_glue_connection.network[0].name,
    aws_glue_connection.network[1].name,
    aws_glue_connection.network[2].name,
  ]

  command {
    name            = "glueetl"
    script_location = "s3://${aws_s3_bucket.medallion.id}/scripts/bronze_ingestion.py"
    python_version  = "3"
  }

  default_arguments = local.glue_default_args
  worker_type       = var.worker_type
  number_of_workers = var.number_of_workers
  timeout           = var.job_timeout_minutes

  execution_property {
    max_concurrent_runs = 1
  }

  tags = local.common_tags

  depends_on = [aws_s3_object.bronze_script]
}

# ── Silver: cleanse & deduplicate ─────────────────────────────────────────────

resource "aws_glue_job" "silver" {
  name         = "${var.project_name}-silver-transformation"
  description  = "Deduplicates, standardises, and type-casts bronze data; writes Parquet to silver layer"
  role_arn     = aws_iam_role.glue.arn
  glue_version = var.glue_version
  connections  = [aws_glue_connection.network[1].name]

  command {
    name            = "glueetl"
    script_location = "s3://${aws_s3_bucket.medallion.id}/scripts/silver_transformation.py"
    python_version  = "3"
  }

  default_arguments = local.glue_default_args
  worker_type       = var.worker_type
  number_of_workers = var.number_of_workers
  timeout           = var.job_timeout_minutes

  execution_property {
    max_concurrent_runs = 1
  }

  tags = local.common_tags

  depends_on = [aws_s3_object.silver_script]
}

# ── Gold: business aggregations ───────────────────────────────────────────────

resource "aws_glue_job" "gold" {
  name         = "${var.project_name}-gold-aggregation"
  description  = "Produces four analytical tables (daily sales, customer LTV, product perf, category) from silver layer"
  role_arn     = aws_iam_role.glue.arn
  glue_version = var.glue_version
  connections  = [aws_glue_connection.network[2].name]

  command {
    name            = "glueetl"
    script_location = "s3://${aws_s3_bucket.medallion.id}/scripts/gold_aggregation.py"
    python_version  = "3"
  }

  default_arguments = local.glue_default_args
  worker_type       = var.worker_type
  number_of_workers = var.number_of_workers
  timeout           = var.job_timeout_minutes

  execution_property {
    max_concurrent_runs = 1
  }

  tags = local.common_tags

  depends_on = [aws_s3_object.gold_script]
}

# ── Workflow: chains the three jobs ──────────────────────────────────────────

resource "aws_glue_workflow" "medallion" {
  name        = "${var.project_name}-workflow"
  description = "Medallion ETL pipeline: Bronze ingestion → Silver cleanse → Gold aggregation"
  tags        = local.common_tags
}

# Trigger 1 – ON_DEMAND: kicks off the bronze job when the workflow is started
resource "aws_glue_trigger" "start_bronze" {
  name          = "${var.project_name}-trigger-bronze"
  type          = "ON_DEMAND"
  workflow_name = aws_glue_workflow.medallion.name

  actions {
    job_name = aws_glue_job.bronze.name
  }

  tags = local.common_tags
}

# Trigger 2 – CONDITIONAL: starts silver after bronze succeeds
resource "aws_glue_trigger" "start_silver" {
  name              = "${var.project_name}-trigger-silver"
  type              = "CONDITIONAL"
  workflow_name     = aws_glue_workflow.medallion.name
  start_on_creation = true

  predicate {
    logical = "AND"
    conditions {
      job_name         = aws_glue_job.bronze.name
      state            = "SUCCEEDED"
      logical_operator = "EQUALS"
    }
  }

  actions {
    job_name = aws_glue_job.silver.name
  }

  tags = local.common_tags
}

# Trigger 3 – CONDITIONAL: starts gold after silver succeeds
resource "aws_glue_trigger" "start_gold" {
  name              = "${var.project_name}-trigger-gold"
  type              = "CONDITIONAL"
  workflow_name     = aws_glue_workflow.medallion.name
  start_on_creation = true

  predicate {
    logical = "AND"
    conditions {
      job_name         = aws_glue_job.silver.name
      state            = "SUCCEEDED"
      logical_operator = "EQUALS"
    }
  }

  actions {
    job_name = aws_glue_job.gold.name
  }

  tags = local.common_tags
}
