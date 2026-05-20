output "default_vpc_id" {
  description = "Auto-detected default VPC ID"
  value       = data.aws_vpc.default.id
}

output "alb_dns_name" {
  description = "Application Load Balancer DNS - open this in your browser"
  value       = "http://${aws_lb.main.dns_name}"
}

output "ec2_instance_id" {
  description = "EC2 Instance ID"
  value       = aws_instance.main.id
}

output "ec2_public_ip" {
  description = "EC2 Public IP"
  value       = aws_instance.main.public_ip
}

output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint (connect from EC2 using psql client)"
  value       = aws_db_instance.postgres.address
}

output "rds_port" {
  description = "RDS PostgreSQL port"
  value       = aws_db_instance.postgres.port
}

output "ec2_connect_info" {
  description = "How to connect to EC2 using EC2 Instance Connect"
  value       = "Use AWS Console EC2 Connect feature for instance ID ${aws_instance.main.id}. No SSH key needed."
}

output "postgresql_connect_command" {
  description = "PostgreSQL connect command (run from EC2)"
  value       = "psql -h ${aws_db_instance.postgres.address} -U ${var.db_username} -d ${var.db_name}"
}

output "rds_secret_arn" {
  description = "Secrets Manager ARN for RDS master credentials"
  value       = aws_secretsmanager_secret.rds_master.arn
}

output "rds_secret_name" {
  description = "Secrets Manager secret name for RDS master credentials"
  value       = aws_secretsmanager_secret.rds_master.name
}
