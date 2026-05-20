# -------------------------------------------------------
# IAM roles required by DMS
# -------------------------------------------------------

# DMS needs this exact role name to manage ENIs in your VPC
resource "aws_iam_role" "dms_vpc_role" {
  name = "dms-vpc-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "dms.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "dms_vpc_role" {
  role       = aws_iam_role.dms_vpc_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonDMSVPCManagementRole"
}

# DMS needs this exact role name to publish logs to CloudWatch
resource "aws_iam_role" "dms_cloudwatch_role" {
  name = "dms-cloudwatch-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "dms.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "dms_cloudwatch_role" {
  role       = aws_iam_role.dms_cloudwatch_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonDMSCloudWatchLogsRole"
}

# -------------------------------------------------------
# Replication instance
# -------------------------------------------------------

resource "aws_dms_replication_subnet_group" "dms" {
  replication_subnet_group_id          = "dms-replication-subnet-group"
  replication_subnet_group_description = "DMS replication subnet group"
  subnet_ids                           = data.aws_subnets.default.ids

  depends_on = [aws_iam_role_policy_attachment.dms_vpc_role]
}

resource "aws_dms_replication_instance" "dms" {
  replication_instance_id    = "dms-replication-instance"
  replication_instance_class = "dms.t3.medium"
  allocated_storage          = 20
  publicly_accessible        = true

  replication_subnet_group_id = aws_dms_replication_subnet_group.dms.id
  vpc_security_group_ids      = [aws_security_group.rds_sg.id]

  depends_on = [aws_iam_role_policy_attachment.dms_vpc_role]
}

# -------------------------------------------------------
# Endpoints
# -------------------------------------------------------

resource "aws_dms_endpoint" "source" {
  endpoint_id   = "source-postgres"
  endpoint_type = "source"
  engine_name   = "postgres"

  server_name   = aws_db_instance.source_rds.address
  port          = 5432
  database_name = var.db_name
  username      = var.dms_username
  password      = var.dms_password
  ssl_mode      = "require"
}

resource "aws_dms_endpoint" "destination" {
  endpoint_id   = "destination-postgres"
  endpoint_type = "target"
  engine_name   = "postgres"

  server_name   = aws_db_instance.destination_rds.address
  port          = 5432
  database_name = var.db_name
  username      = var.db_username
  password      = var.db_password
  ssl_mode      = "require"
}

# -------------------------------------------------------
# Migration task
# -------------------------------------------------------

resource "aws_dms_replication_task" "migration" {
  replication_task_id      = "dms-migration-task"
  replication_instance_arn = aws_dms_replication_instance.dms.replication_instance_arn
  source_endpoint_arn      = aws_dms_endpoint.source.endpoint_arn
  target_endpoint_arn      = aws_dms_endpoint.destination.endpoint_arn

  migration_type = var.migration_type  # full-load | cdc | full-load-and-cdc

  table_mappings = jsonencode({
    rules = [
      {
        rule-type   = "selection"
        rule-id     = "1"
        rule-name   = "include-public"
        rule-action = "include"
        object-locator = {
          schema-name = "public"
          table-name  = "%"
        }
      },
      {
        rule-type   = "selection"
        rule-id     = "2"
        rule-name   = "include-hrms"
        rule-action = "include"
        object-locator = {
          schema-name = "hrms"
          table-name  = "%"
        }
      }
    ]
  })

  replication_task_settings = jsonencode({
    TargetMetadata = {
      TargetSchema              = ""
      SupportLobs               = true
      FullLobMode               = false
      LobChunkSize              = 64
      LimitedSizeLobMode        = true
      LobMaxSize                = 32
    }
    FullLoadSettings = {
      TargetTablePrepMode       = "DROP_AND_CREATE"
      CreatePkAfterFullLoad     = false
      StopTaskCachedChangesApplied  = false
      StopTaskCachedChangesNotApplied = false
      MaxFullLoadSubTasks       = 8
      TransactionConsistencyTimeout = 600
      CommitRate                = 50000
    }
    Logging = {
      EnableLogging             = true
      LogComponents = [
        { Id = "SOURCE_UNLOAD", Severity = "LOGGER_SEVERITY_DEFAULT" },
        { Id = "TARGET_LOAD",   Severity = "LOGGER_SEVERITY_DEFAULT" },
        { Id = "TASK_MANAGER",  Severity = "LOGGER_SEVERITY_DEFAULT" }
      ]
    }
  })
}
