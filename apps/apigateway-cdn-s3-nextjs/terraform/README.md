# Terraform Configuration for Next.js App on S3 + CloudFront CDN

This Terraform configuration deploys a Next.js application to AWS using S3 for storage and CloudFront as the CDN, with TLS/SSL enabled via ACM certificate.

## Architecture Overview

```
                                    ┌─────────────────────┐
                                    │  Route53 DNS Zone   │
                                    │  (example.com)        │
                                    └──────────┬──────────┘
                                               │
                                         CNAME Records
                                               │
                    ┌──────────────────────────┼──────────────────────────┐
                    │                          │                          │
                    ▼                          ▼                          ▼
            ┌─────────────────┐      ┌─────────────────────┐     ┌──────────────┐
            │  Route53 Record │      │  ACM Certificate    │     │  CloudFront  │
            │  app.example...     │      │  *.example.com        │     │  Distribution│
            └─────────────────┘      └──────────┬──────────┘     └──────┬───────┘
                                               │                        │
                                         SSL/TLS Connection              │
                                               │                        │
                                               │         Origin Access  │
                                               │         Control (OAC)  │
                                               │                        │
                                               ▼                        ▼
                                          ┌────────────────────────────────┐
                                          │      S3 Bucket (Private)       │
                                          │   - Static HTML files          │
                                          │   - Next.js assets (_next/*)   │
                                          │   - Images & media             │
                                          └────────────────────────────────┘
```

## Prerequisites

1. **AWS Account**: You need an active AWS account with appropriate permissions
2. **AWS Credentials**: Configure your AWS credentials locally
   ```bash
   aws configure
   ```
3. **Terraform**: Install Terraform v1.0 or later
   ```bash
   terraform --version
   ```
4. **ACM Certificate**: Ensure a wildcard certificate for `*.example.com` exists in ACM in the **us-east-1** region
   - CloudFront requires SSL certificates to be in us-east-1
5. **Route53 Hosted Zone**: The `example.com` domain must have an existing Route53 hosted zone
6. **Node.js Project**: Next.js application configured for static export

## File Structure

```
terraform/
├── main.tf                          # Provider and common configuration
├── variables.tf                     # Variable definitions
├── outputs.tf                       # Output definitions
├── s3.tf                           # S3 bucket configuration
├── cloudfront.tf                   # CloudFront distribution configuration
├── route53.tf                      # DNS routing configuration
├── cloudfront-function.js          # CloudFront function for URL rewriting
├── terraform.tfvars.example        # Example variables file
├── terraform.tfvars                # Actual variables (create from example)
├── .gitignore                      # Git ignore file
└── README.md                       # This file
```

## Setup Instructions

### 1. Initialize Terraform

```bash
cd terraform
terraform init
```

### 2. Create terraform.tfvars

Copy the example file and update with your values:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:
- Set `route53_zone_id` to your hosted zone ID
- Verify other values match your requirements

**To find your Route53 Hosted Zone ID:**
```bash
aws route53 list-hosted-zones-by-name --dns-name example.com
```

### 3. Validate Configuration

```bash
terraform validate
terraform plan
```

### 4. Deploy Infrastructure

```bash
terraform apply
```

Review the plan output and type `yes` to confirm deployment.

## Configuring the Next.js Application

Ensure your `next.config.ts` includes the static export configuration:

```typescript
import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  output: 'export',
  trailingSlash: true,
  images: {
    unoptimized: true,
  },
};

export default nextConfig;
```

## Building and Deploying

### 1. Build the Next.js Application

```bash
npm run build
```

This creates a static `out/` directory with all pages exported.

### 2. Upload to S3

After successful terraform apply, use the provided command from outputs:

```bash
aws s3 sync ./out s3://app-dev-us-east-1/ --delete \
  --cache-control 'public, max-age=3600' \
  --exclude '*.map' \
  --region us-east-1
```

Set appropriate cache headers for different file types:

```bash
# Upload HTML files (cache for 1 hour)
aws s3 sync ./out s3://app-dev-us-east-1/ \
  --include "*.html" \
  --cache-control 'public, max-age=3600' \
  --region us-east-1

# Upload JS/CSS files (cache for 1 year, they have hashes)
aws s3 sync ./out s3://app-dev-us-east-1/ \
  --include "_next/*" \
  --cache-control 'public, max-age=31536000, immutable' \
  --region us-east-1

# Upload everything else
aws s3 sync ./out s3://app-dev-us-east-1/ \
  --cache-control 'public, max-age=86400' \
  --exclude "*.html" \
  --exclude "_next/*" \
  --region us-east-1
```

### 3. Invalidate CloudFront Cache

After uploading, invalidate the CloudFront distribution to ensure users get the latest version:

```bash
aws cloudfront create-invalidation \
  --distribution-id <DISTRIBUTION_ID> \
  --paths "/*" \
  --region us-east-1
```

Get the distribution ID from:
```bash
terraform output cloudfront_distribution_id
```

### 4. Access Your Application

```bash
terraform output application_url
```

Or visit: `https://app-dev.example.com`

## Configuration Details

### S3 Bucket

- **Public Access**: Blocked - only CloudFront can access
- **Versioning**: Enabled for rollback capability
- **Encryption**: AES256 server-side encryption enabled
- **Logging**: Access logs stored in the same bucket
- **CORS**: Configured for the application domain

### CloudFront Distribution

- **Origin**: S3 bucket with Origin Access Control (OAC)
- **SSL/TLS**: Uses ACM certificate for `*.example.com`
- **Protocol**: HTTPS only (HTTP redirects to HTTPS)
- **Compression**: Gzip and Brotli compression enabled
- **Caching**: 
  - HTML: 3600 seconds (1 hour)
  - Static assets (_next/*): 86400 seconds (24 hours)
- **URL Rewriting**: CloudFront function handles SPA routing

### CloudFront Function

The `cloudfront-function.js` handles:
- Static asset requests (with extensions) - pass through
- Root path (/) - pass through
- API routes (_next/api) - pass through
- All other routes - rewrite to index.html for SPA routing

### DNS (Route53)

- **A Record**: Points `app-dev.example.com` to CloudFront distribution
- **AAAA Record**: IPv6 support for CloudFront

## Cache Behaviors

### HTML Files
- **TTL**: 0 minutes (minimum) to 1 hour (default)
- **Query strings**: Forwarded
- **Compression**: Enabled

### Static Assets (_next/*)
- **TTL**: 0 minutes (minimum) to 24 hours (maximum)
- **Query strings**: Not forwarded (they have content hashes)
- **Compression**: Enabled

## Cost Optimization

1. **S3 Storage**: Minimal cost (only stores static files)
2. **CloudFront**: 
   - Adjust `cloudfront_price_class` for different regions:
     - `PriceClass_100`: North America, Europe, Asia, Middle East, Africa (cheapest)
     - `PriceClass_200`: Adds Australia, more European points
     - `PriceClass_All`: All regions (most expensive)
3. **Data Transfer**: CloudFront reduces origin bandwidth costs

## Monitoring

View CloudFront statistics:

```bash
aws cloudfront list-distributions --query "DistributionList.Items[?DomainName=='*.cloudfront.net']"
```

View CloudWatch metrics:

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/CloudFront \
  --metric-name Requests \
  --dimensions Name=DistributionId,Value=<DISTRIBUTION_ID> \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-01T12:00:00Z \
  --period 3600 \
  --statistics Sum
```

## Troubleshooting

### CloudFront Returns 403 Errors

1. Verify S3 bucket policy is correctly configured
2. Check Origin Access Control is attached to CloudFront
3. Ensure files are uploaded to S3

### DNS Not Resolving

1. Verify Route53 hosted zone ID is correct
2. Check that Route53 nameservers are set in domain registrar
3. Wait up to 48 hours for DNS propagation

### SSL Certificate Issues

1. Verify certificate is in **us-east-1** region (required for CloudFront)
2. Check certificate domain matches the CloudFront CNAME
3. Ensure certificate status is "ISSUED"

```bash
aws acm list-certificates --region us-east-1
```

### Cache Not Clearing

Invalidating CloudFront cache:
```bash
aws cloudfront create-invalidation \
  --distribution-id <DISTRIBUTION_ID> \
  --paths "/*"
```

## Maintenance

### Update Terraform

```bash
terraform plan -out=tfplan
terraform apply tfplan
```

### Destroy Infrastructure

```bash
# Delete all objects from S3 first (Terraform won't delete non-empty buckets)
aws s3 rm s3://app-dev-us-east-1/ --recursive

# Then destroy
terraform destroy
```

## Variables Reference

| Variable | Default | Description |
|----------|---------|-------------|
| `aws_region` | `us-east-1` | AWS region (CloudFront requires us-east-1 for cert) |
| `environment` | `dev` | Environment name |
| `project_name` | `app` | Project name |
| `domain_name` | `app-dev.example.com` | Custom domain name |
| `certificate_domain` | `*.example.com` | ACM certificate domain |
| `s3_bucket_versioning` | `true` | Enable S3 versioning |
| `cloudfront_price_class` | `PriceClass_100` | CloudFront price class |
| `cf_default_ttl` | `3600` | Default cache TTL in seconds |
| `cf_max_ttl` | `86400` | Maximum cache TTL in seconds |
| `cf_min_ttl` | `0` | Minimum cache TTL in seconds |
| `route53_zone_id` | `` | Route53 hosted zone ID (required) |
| `index_document` | `index.html` | Default index document |
| `error_document` | `404.html` | Error page document |

## Advanced Configuration

### Using Remote State

Uncomment the backend configuration in `main.tf` to store state remotely:

```hcl
backend "s3" {
  bucket         = "terraform-state-zamait"
  key            = "app/dev/terraform.tfstate"
  region         = "us-east-1"
  encrypt        = true
  dynamodb_table = "terraform-locks"
}
```

### Custom Headers

Add custom headers to CloudFront requests:

```hcl
custom_header {
  name  = "X-Custom-Header"
  value = "your-value"
}
```

### Security Headers

Add security headers via CloudFront response headers policy (requires additional configuration).

## Support & Additional Resources

- [AWS CloudFront Documentation](https://docs.aws.amazon.com/cloudfront/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Next.js Static Export](https://nextjs.org/docs/app/building-your-application/deploying/static-exports)
- [CloudFront Functions](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/cloudfront-functions.html)

## License

This Terraform configuration is provided as-is for use with the Next.js application.
