# ─────────────────────────────────────────────────────────────────────────────
# Outputs
# ─────────────────────────────────────────────────────────────────────────────

output "app_url" {
  description = "Open this in your browser — wait 4-5 mins after apply for Flask to start"
  value       = "http://${aws_instance.poc.public_ip}:5000"
}

output "ssh_command" {
  description = "SSH into EC2"
  value       = "ssh -i ${var.key_pair_name}.pem ec2-user@${aws_instance.poc.public_ip}"
}

output "ec2_public_ip" {
  description = "EC2 public IP address"
  value       = aws_instance.poc.public_ip
}

output "vpc_id" {
  description = "VPC ID created for this POC"
  value       = aws_vpc.poc.id
}

output "public_subnet_id" {
  description = "Public subnet ID"
  value       = aws_subnet.public.id
}

output "s3_bucket_name" {
  description = "S3 bucket created for this POC"
  value       = aws_s3_bucket.poc.id
}

output "s3_bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.poc.arn
}

output "vpc_endpoint_id" {
  description = "VPC Gateway Endpoint ID — verify in VPC Route Tables"
  value       = aws_vpc_endpoint.s3.id
}

output "iam_role_arn" {
  description = "IAM role ARN attached to EC2"
  value       = aws_iam_role.ec2_s3.arn
}

output "check_flask_logs" {
  description = "Run on EC2 to check Flask app logs"
  value       = "sudo journalctl -u s3-poc -f"
}

output "check_userdata_logs" {
  description = "Run on EC2 to check UserData installation logs"
  value       = "sudo cat /var/log/userdata.log"
}

output "verify_s3_access" {
  description = "Run on EC2 to verify S3 access goes through endpoint"
  value       = "aws s3 ls s3://${aws_s3_bucket.poc.id} --region ${var.aws_region}"
}

output "verify_route_table" {
  description = "Check this in AWS Console to confirm endpoint route"
  value       = "VPC -> Route Tables -> ${aws_route_table.public.id} -> Routes tab -> look for pl-XXXXX -> ${aws_vpc_endpoint.s3.id}"
}

output "cleanup_command" {
  description = "Destroy all resources created by this template"
  value       = "terraform destroy -auto-approve"
}
