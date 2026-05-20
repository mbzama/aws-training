output "default_vpc_id" {
  description = "Auto-detected default VPC ID"
  value       = data.aws_vpc.default.id
}

output "cluster_endpoint" {
  description = "Redshift cluster endpoint address"
  value       = aws_redshift_cluster.main.endpoint
}

output "cluster_port" {
  description = "Redshift cluster port"
  value       = aws_redshift_cluster.main.port
}

output "cluster_jdbc_url" {
  description = "JDBC connection URL for SQL clients (e.g. DBeaver, SQL Workbench/J)"
  value       = "jdbc:redshift://${aws_redshift_cluster.main.endpoint}:${aws_redshift_cluster.main.port}/${var.db_name}"
}

output "psql_connect_command" {
  description = "psql connect command (requires PostgreSQL client v8+ or Redshift driver)"
  value       = "psql -h ${aws_redshift_cluster.main.endpoint} -p ${aws_redshift_cluster.main.port} -U ${var.db_username} -d ${var.db_name}"
}

output "postgresql_endpoint" {
  description = "PostgreSQL RDS endpoint (reachable from Redshift via port 5432)"
  value       = aws_db_instance.postgres.address
}

output "postgresql_port" {
  description = "PostgreSQL RDS port"
  value       = aws_db_instance.postgres.port
}

output "postgresql_connect_command" {
  description = "psql command to connect to PostgreSQL from a host with network access to the RDS instance"
  value       = "psql -h ${aws_db_instance.postgres.address} -U ${var.pg_username} -d ${var.pg_db_name}"
}

output "redshift_secret_arn" {
  description = "Secrets Manager ARN for Redshift master credentials"
  value       = aws_secretsmanager_secret.redshift_master.arn
}

output "postgresql_secret_arn" {
  description = "Secrets Manager ARN for PostgreSQL master credentials"
  value       = aws_secretsmanager_secret.postgres_master.arn
}
