output "bucket_name" {
  description = "S3 bucket holding Lambda deployment packages"
  value       = aws_s3_bucket.lambda_artifacts.id
}

output "api_endpoint" {
  description = "HTTP API endpoint URL"
  value       = module.api_gateway.api_endpoint
}

output "stage_invoke_url" {
  description = "Full invoke URL for the deployed stage"
  value       = module.api_gateway.stage_invoke_url
}

output "pets_url" {
  description = "Example URL to call the /pets endpoint"
  value       = "${module.api_gateway.stage_invoke_url}/pets"
}

output "authorizer_function_name" {
  description = "Name of the deployed authorizer Lambda"
  value       = module.lambda_authorizer.function_name
}

output "backend_function_name" {
  description = "Name of the deployed backend Lambda"
  value       = module.lambda_backend.function_name
}

output "authorizer_log_group" {
  description = "CloudWatch log group for the authorizer Lambda"
  value       = module.lambda_authorizer.log_group_name
}

output "backend_log_group" {
  description = "CloudWatch log group for the backend Lambda"
  value       = module.lambda_backend.log_group_name
}

output "api_id" {
  description = "HTTP API ID"
  value       = module.api_gateway.api_id
}
