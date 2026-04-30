# API Gateway HTTP API - entry point for the application
resource "aws_apigatewayv2_api" "app_api" {
  name          = "${var.project_name}-${var.environment}-api"
  protocol_type = "HTTP"
  description   = "HTTP API for ${var.project_name}-${var.environment}"

  tags = local.common_tags
}

# HTTP Proxy integration - forward all traffic to CloudFront
resource "aws_apigatewayv2_integration" "cloudfront_proxy" {
  api_id             = aws_apigatewayv2_api.app_api.id
  integration_type   = "HTTP_PROXY"
  integration_method = "ANY"
  integration_uri    = "https://${aws_cloudfront_distribution.app_distribution.domain_name}"

  # 1.0 handles binary payloads (images, fonts, etc.) correctly
  payload_format_version = "1.0"
}

# $default route - catches all requests and forwards to CloudFront
resource "aws_apigatewayv2_route" "default" {
  api_id    = aws_apigatewayv2_api.app_api.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.cloudfront_proxy.id}"
}

# Auto-deploy stage
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.app_api.id
  name        = "$default"
  auto_deploy = true

  tags = local.common_tags
}

# Custom domain name for API Gateway using *.example.com cert
resource "aws_apigatewayv2_domain_name" "app_domain" {
  domain_name = var.domain_name

  domain_name_configuration {
    certificate_arn = data.aws_acm_certificate.app_cert.arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }

  tags = local.common_tags
}

# Map API to custom domain
resource "aws_apigatewayv2_api_mapping" "app_mapping" {
  api_id      = aws_apigatewayv2_api.app_api.id
  domain_name = aws_apigatewayv2_domain_name.app_domain.id
  stage       = aws_apigatewayv2_stage.default.id
}
