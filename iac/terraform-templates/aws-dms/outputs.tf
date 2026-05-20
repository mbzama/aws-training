output "source_rds_endpoint" {
  description = "Source Aurora cluster writer endpoint"
  value       = aws_rds_cluster.source.endpoint
}

output "destination_rds_endpoint" {
  description = "Destination Aurora cluster writer endpoint"
  value       = aws_rds_cluster.destination.endpoint
}

output "db_port" {
  value = 5432
}

output "db_name" {
  value = var.db_name
}

output "dms_replication_instance_arn" {
  value = aws_dms_replication_instance.dms.replication_instance_arn
}

output "dms_task_arn" {
  value = aws_dms_replication_task.migration.replication_task_arn
}
