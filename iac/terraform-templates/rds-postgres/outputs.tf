output "default_vpc_id" {
  description = "Auto-detected default VPC ID"
  value       = data.aws_vpc.default.id
}

output "rds_endpoint" {
  description = "PostgreSQL endpoint hostname"
  value       = aws_db_instance.postgres.address
}

output "rds_port" {
  description = "PostgreSQL port"
  value       = aws_db_instance.postgres.port
}

output "rds_master_secret_arn" {
  description = "ARN of the Secrets Manager secret containing the master password"
  value       = aws_secretsmanager_secret.rds_master.arn
}

output "rds_master_secret_name" {
  description = "Name of the Secrets Manager secret"
  value       = aws_secretsmanager_secret.rds_master.name
}

output "psql_connect_command" {
  description = "psql connection command (password stored in Secrets Manager)"
  value       = "psql -h ${aws_db_instance.postgres.address} -U ${var.db_username} -d ${var.db_name}"
}

output "jdbc_connection_string" {
  description = "JDBC connection string (Java / Spring Boot)"
  value       = "jdbc:postgresql://${aws_db_instance.postgres.address}:5432/${var.db_name}"
}
