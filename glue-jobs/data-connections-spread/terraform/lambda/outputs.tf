output "lambda_role_arn" {
  description = "ARN of the Lambda IAM role"
  value       = aws_iam_role.lambda.arn
}

output "private_subnet_2_id" {
  description = "ID of private-subnet-2 (used as SUBNET_ID for check-ips and clean-ips)"
  value       = data.aws_subnet.private_2.id
}
