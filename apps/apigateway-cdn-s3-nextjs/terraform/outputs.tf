output "s3_bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.app_bucket.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.app_bucket.arn
}

output "s3_bucket_region_domain" {
  description = "Regional domain name of the S3 bucket"
  value       = aws_s3_bucket.app_bucket.bucket_regional_domain_name
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.app_distribution.id
}

output "cloudfront_distribution_arn" {
  description = "CloudFront distribution ARN"
  value       = aws_cloudfront_distribution.app_distribution.arn
}

output "cloudfront_distribution_domain_name" {
  description = "CloudFront distribution domain name (internal - API Gateway routes to this)"
  value       = aws_cloudfront_distribution.app_distribution.domain_name
}

output "api_gateway_id" {
  description = "API Gateway HTTP API ID"
  value       = aws_apigatewayv2_api.app_api.id
}

output "api_gateway_endpoint" {
  description = "API Gateway default endpoint (without custom domain)"
  value       = aws_apigatewayv2_api.app_api.api_endpoint
}

output "api_gateway_target_domain_name" {
  description = "Target domain name for GoDaddy CNAME record (app-dev → this value)"
  value       = aws_apigatewayv2_domain_name.app_domain.domain_name_configuration[0].target_domain_name
}

output "cloudfront_etag" {
  description = "CloudFront distribution ETag"
  value       = aws_cloudfront_distribution.app_distribution.etag
}

output "application_url" {
  description = "URL to access the application"
  value       = "https://${var.domain_name}"
}

output "cloudfront_domain_name" {
  description = "CloudFront domain name (internal - do NOT use for GoDaddy CNAME, use api_gateway_target_domain_name instead)"
  value       = aws_cloudfront_distribution.app_distribution.domain_name
}

output "certificate_arn" {
  description = "ACM Certificate ARN used"
  value       = data.aws_acm_certificate.app_cert.arn
}

output "certificate_domain" {
  description = "Certificate domain"
  value       = data.aws_acm_certificate.app_cert.domain
}

output "s3_upload_command" {
  description = "Command to upload built Next.js files to S3"
  value       = "aws s3 sync ./dist s3://${aws_s3_bucket.app_bucket.id}/ --delete --cache-control 'public, max-age=3600' --exclude '*.map' --region ${var.aws_region}"
}

output "invalidate_cloudfront_command" {
  description = "Command to invalidate CloudFront cache"
  value       = "aws cloudfront create-invalidation --distribution-id ${aws_cloudfront_distribution.app_distribution.id} --paths '/*' --region ${var.aws_region}"
}

output "deployment_instructions" {
  description = "Instructions for deploying the application"
  value       = "1. Build: npm run build\n2. Deploy: ./deploy.sh\n3. Add CNAME in GoDaddy: app-dev → ${aws_apigatewayv2_domain_name.app_domain.domain_name_configuration[0].target_domain_name}\n4. Access: https://${var.domain_name}"
}
