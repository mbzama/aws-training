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
