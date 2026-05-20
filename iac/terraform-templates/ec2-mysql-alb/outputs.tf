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
  description = "EC2 Public IP (SSH access)"
  value       = aws_instance.main.public_ip
}

output "rds_endpoint" {
  description = "RDS MySQL endpoint (connect from EC2 using mysql client)"
  value       = aws_db_instance.mysql.address
}

output "rds_port" {
  description = "RDS MySQL port"
  value       = aws_db_instance.mysql.port
}

output "ssh_command" {
  description = "SSH command to connect to EC2"
  value       = "ssh -i <your-key>.pem ec2-user@${aws_instance.main.public_ip}"
}

output "mysql_connect_command" {
  description = "MySQL connect command (run from EC2; password in Secrets Manager)"
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
