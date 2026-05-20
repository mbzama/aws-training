output "api_id" {
  description = "HTTP API ID"
  value       = aws_apigatewayv2_api.this.id
}

output "api_endpoint" {
  description = "HTTP API endpoint URL"
  value       = aws_apigatewayv2_api.this.api_endpoint
}

output "stage_invoke_url" {
  description = "Full invoke URL including stage"
  value       = "${aws_apigatewayv2_api.this.api_endpoint}/${var.stage_name}"
}

output "execution_arn" {
  description = "API Gateway execution ARN"
  value       = aws_apigatewayv2_api.this.execution_arn
}

output "authorizer_id" {
  description = "Lambda authorizer ID"
  value       = aws_apigatewayv2_authorizer.this.id
}
