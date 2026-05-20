# Data source to find the imported ACM certificate for example.com
# Looks for an IMPORTED type cert covering example.com in us-east-1 (required by CloudFront + API Gateway)
# key_types includes EC_prime256v1 because ACM list API omits non-RSA certs by default
data "aws_acm_certificate" "app_cert" {
  provider    = aws.us_east_1
  domain      = var.certificate_domain
  statuses    = ["ISSUED"]
  types       = ["IMPORTED"]
  key_types   = ["EC_prime256v1", "RSA_2048", "RSA_4096"]
  most_recent = true
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "app_distribution" {
  origin {
    domain_name              = aws_s3_bucket.app_bucket.bucket_regional_domain_name
    origin_id                = "S3-${local.bucket_name}"
    origin_access_control_id = aws_cloudfront_origin_access_control.app_oac.id

    custom_header {
      name  = "X-Custom-Header"
      value = "${var.project_name}-${var.environment}"
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Distribution for ${var.project_name}-${var.environment}"
  default_root_object = var.index_document
  price_class         = var.cloudfront_price_class

  # Cache behavior for HTML files (index.html, 404.html, etc.)
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${local.bucket_name}"

    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    # Custom cache settings for HTML
    cache_policy_id = aws_cloudfront_cache_policy.html_policy.id

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.url_rewrite.arn
    }
  }

  # Cache behavior for static assets (.js, .css, images, etc.)
  ordered_cache_behavior {
    path_pattern     = "/_next/*"
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${local.bucket_name}"

    compress               = true
    viewer_protocol_policy = "https-only"
    cache_policy_id        = aws_cloudfront_cache_policy.static_policy.id
  }

  # CloudFront uses its default certificate - API Gateway handles the custom domain
  viewer_certificate {
    cloudfront_default_certificate = true
  }

  # Geo-restriction (optional)
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # Custom error responses
  custom_error_response {
    error_code            = 404
    error_caching_min_ttl = 300
    response_code         = 200
    response_page_path    = "/${var.error_document}"
  }

  custom_error_response {
    error_code            = 403
    error_caching_min_ttl = 300
    response_code         = 200
    response_page_path    = "/${var.index_document}"
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-distribution"
    }
  )

}

# CloudFront Cache Policy for static assets
resource "aws_cloudfront_cache_policy" "static_policy" {
  name        = "${var.project_name}-${var.environment}-static-cache-policy"
  comment     = "Cache policy for static assets"
  default_ttl = var.cf_default_ttl
  max_ttl     = var.cf_max_ttl
  min_ttl     = var.cf_min_ttl

  parameters_in_cache_key_and_forwarded_to_origin {
    enable_accept_encoding_gzip   = true
    enable_accept_encoding_brotli = true

    query_strings_config {
      query_string_behavior = "none"
    }

    headers_config {
      header_behavior = "none"
    }

    cookies_config {
      cookie_behavior = "none"
    }
  }
}

# CloudFront Cache Policy for HTML files
resource "aws_cloudfront_cache_policy" "html_policy" {
  name        = "${var.project_name}-${var.environment}-html-cache-policy"
  comment     = "Cache policy for HTML files"
  default_ttl = 3600
  max_ttl     = 86400
  min_ttl     = 0

  parameters_in_cache_key_and_forwarded_to_origin {
    enable_accept_encoding_gzip   = true
    enable_accept_encoding_brotli = true

    query_strings_config {
      query_string_behavior = "all"
    }

    headers_config {
      header_behavior = "whitelist"
      headers {
        items = ["Accept"]
      }
    }

    cookies_config {
      cookie_behavior = "all"
    }
  }
}

# CloudFront Function for URL rewriting (SPA fallback)
resource "aws_cloudfront_function" "url_rewrite" {
  name    = "${var.project_name}-${var.environment}-url-rewrite"
  runtime = "cloudfront-js-1.0"
  publish = true
  code    = file("${path.module}/cloudfront-function.js")
}

