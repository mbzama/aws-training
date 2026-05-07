output "s3_bucket_name" {
  description = "Name of the S3 bucket holding all medallion layers"
  value       = aws_s3_bucket.medallion.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.medallion.arn
}

output "glue_role_arn" {
  description = "ARN of the IAM role assumed by Glue jobs"
  value       = aws_iam_role.glue.arn
}

output "glue_job_names" {
  description = "Names of all three Glue ETL jobs"
  value = {
    bronze = aws_glue_job.bronze.name
    silver = aws_glue_job.silver.name
    gold   = aws_glue_job.gold.name
  }
}

output "workflow_name" {
  description = "Glue workflow name — start this to run the full pipeline"
  value       = aws_glue_workflow.medallion.name
}

output "s3_layer_paths" {
  description = "S3 paths for each medallion layer"
  value = {
    bronze   = "s3://${aws_s3_bucket.medallion.id}/bronze/"
    silver   = "s3://${aws_s3_bucket.medallion.id}/silver/"
    gold     = "s3://${aws_s3_bucket.medallion.id}/gold/"
    scripts  = "s3://${aws_s3_bucket.medallion.id}/scripts/"
    logs     = "s3://${aws_s3_bucket.medallion.id}/spark-logs/"
  }
}

output "run_workflow_command" {
  description = "AWS CLI command to start the full medallion pipeline"
  value       = "aws glue start-workflow-run --name ${aws_glue_workflow.medallion.name} --region ${var.aws_region}"
}

output "vpc_id" {
  description = "ID of the project VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of the two public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the three private subnets (used by Glue jobs)"
  value       = aws_subnet.private[*].id
}

output "glue_security_group_id" {
  description = "ID of the security group attached to Glue workers"
  value       = aws_security_group.glue.id
}

output "glue_connection_names" {
  description = "Glue network connection names mapped to their private subnet"
  value = {
    for i, c in aws_glue_connection.network :
    c.name => aws_subnet.private[i].cidr_block
  }
}

output "nat_gateway_public_ip" {
  description = "Public IP of the NAT Gateway (egress IP for private subnet traffic)"
  value       = aws_eip.nat.public_ip
}

output "lambda_ip_waiter_arn" {
  description = "ARN of the IP-exhaustion test Lambda"
  value       = aws_lambda_function.ip_waiter.arn
}

output "invoke_ip_waiter_command" {
  description = "CLI command to fire one async Lambda invocation (holds an ENI for WAIT_SECONDS)"
  value       = "aws lambda invoke --function-name ${aws_lambda_function.ip_waiter.function_name} --invocation-type Event --region ${var.aws_region} response.json"
}
