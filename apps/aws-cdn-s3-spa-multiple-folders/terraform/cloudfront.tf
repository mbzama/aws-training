# Origin Access Control — lets CloudFront sign requests to private S3
resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "${var.bucket_name}-oac"
  description                       = "OAC for ${var.bucket_name}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront Function: rewrite SPA sub-paths to the correct index.html
# e.g. /users/profile  →  /users/index.html
#      /movies/123     →  /movies/index.html
resource "aws_cloudfront_function" "spa_rewrite" {
  name    = "${replace(var.bucket_name, "-", "_")}_spa_rewrite"
  runtime = "cloudfront-js-2.0"
  comment = "Rewrite SPA client-side routes to index.html"
  publish = true

  code = <<-EOT
    function handler(event) {
      var request = event.request;
      var uri = request.uri;

      // Strip query string from extension check
      var path = uri.split('?')[0];

      if (path.startsWith('/users') && !path.match(/\.[a-zA-Z0-9]+$/)) {
        request.uri = '/users/index.html';
      } else if (path.startsWith('/movies') && !path.match(/\.[a-zA-Z0-9]+$/)) {
        request.uri = '/movies/index.html';
      }

      return request;
    }
  EOT
}

locals {
  spa_cache = {
    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }
}

resource "aws_cloudfront_distribution" "cdn" {
  origin {
    domain_name              = aws_s3_bucket.spa.bucket_regional_domain_name
    origin_id                = "S3-${var.bucket_name}"
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CDN for users and movies SPAs — ${var.alternate_domain}"
  default_root_object = "index.html"

  # Custom domain alias. DNS must have a CNAME pointing to the cloudfront_domain output.
  aliases = [var.alternate_domain]

  # ── /users* (matches /users and /users/*) ────────────────────────────────
  ordered_cache_behavior {
    path_pattern     = "/users*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${var.bucket_name}"
    compress         = true

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = local.spa_cache.min_ttl
    default_ttl            = local.spa_cache.default_ttl
    max_ttl                = local.spa_cache.max_ttl

    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.spa_rewrite.arn
    }
  }

  # ── /movies* (matches /movies and /movies/*) ──────────────────────────────
  ordered_cache_behavior {
    path_pattern     = "/movies*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${var.bucket_name}"
    compress         = true

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = local.spa_cache.min_ttl
    default_ttl            = local.spa_cache.default_ttl
    max_ttl                = local.spa_cache.max_ttl

    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.spa_rewrite.arn
    }
  }

  # ── Default (fallback) ────────────────────────────────────────────────────
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${var.bucket_name}"
    compress         = true

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400

    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }
  }

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # Custom SSL certificate (us-east-1, required by CloudFront).
  viewer_certificate {
    acm_certificate_arn      = var.acm_certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
