output "rds_endpoint" {
  description = "MySQL endpoint hostname"
  value       = aws_db_instance.mysql.address
}

output "rds_port" {
  description = "MySQL port"
  value       = aws_db_instance.mysql.port
}

output "mysql_connect_command" {
  description = "mysql CLI connection command (password in Secrets Manager)"
  value       = "mysql -h ${aws_db_instance.mysql.address} -u ${var.db_username} ${var.db_name}"
}

output "rds_master_secret_arn" {
  description = "ARN of the Secrets Manager secret containing the master password"
  value       = aws_secretsmanager_secret.rds_master.arn
}

output "rds_master_secret_name" {
  description = "Name of the Secrets Manager secret"
  value       = aws_secretsmanager_secret.rds_master.name
}

output "jdbc_connection_string" {
  description = "JDBC connection string (Java / Spring Boot)"
  value       = "jdbc:mysql://${aws_db_instance.mysql.address}:3306/${var.db_name}"
}
