output "bucket_name" {
  description = "S3 bucket name"
  value       = aws_s3_bucket.spa.id
}

output "bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.spa.arn
}

output "cloudfront_domain" {
  description = "CloudFront distribution domain (use this as the CNAME target in DNS)"
  value       = aws_cloudfront_distribution.cdn.domain_name
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID (needed for cache invalidation)"
  value       = aws_cloudfront_distribution.cdn.id
}

output "landing_url" {
  description = "Landing page URL"
  value       = "https://${var.alternate_domain}/"
}

output "users_url" {
  description = "Users SPA URL"
  value       = "https://${var.alternate_domain}/users"
}

output "movies_url" {
  description = "Movies SPA URL"
  value       = "https://${var.alternate_domain}/movies"
}

output "dns_instruction" {
  description = "DNS record to create after apply"
  value       = "CNAME  ${var.alternate_domain}  →  ${aws_cloudfront_distribution.cdn.domain_name}"
}
