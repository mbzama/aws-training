# Quick Start Guide: Next.js on S3 + CloudFront CDN

This guide will get your Next.js application deployed on AWS S3 with CloudFront CDN in 5 minutes.

## Prerequisites

Before starting, ensure you have:

1. **AWS Account** - with appropriate permissions (S3, CloudFront, ACM, Route53)
2. **AWS CLI** - installed and configured: `aws configure`
3. **Terraform** - v1.0+: Install from https://www.terraform.io/
4. **Node.js** - v18+ for Next.js
5. **ACM Certificate** - wildcard certificate `*.zamait.in` already created in **us-east-1**
6. **Route53** - hosted zone for `zamait.in` already configured
7. **Route53 Zone ID** - You'll need this, find it with:
   ```bash
   aws route53 list-hosted-zones-by-name --dns-name zamait.in
   ```

## Step 1: Configure Terraform Variables (2 min)

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and update:
- `route53_zone_id`: Your hosted zone ID from the command above

Other values are pre-configured:
- Domain: `app-dev.zamait.in`
- Certificate: `*.zamait.in`
- Region: `us-east-1` (required for CloudFront)

## Step 2: Initialize and Deploy Infrastructure (3 min)

```bash
# Initialize Terraform (download providers)
make init

# Review the plan
make plan

# Deploy (review output, type 'yes' to confirm)
make apply
```

This creates:
- ✓ S3 bucket (private, encrypted)
- ✓ CloudFront distribution
- ✓ DNS records in Route53
- ✓ TLS/SSL with ACM certificate

**Save the outputs!** You'll see:
- `s3_bucket_name`: Your S3 bucket
- `cloudfront_distribution_id`: Your CloudFront ID
- `application_url`: Your live URL
- `deployment_instructions`: Detailed steps

## Step 3: Configure Next.js for Static Export

Ensure your `next.config.ts` has static export enabled:

```typescript
import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  output: 'export',        // Static export
  trailingSlash: true,     // Add trailing slashes to pages
  images: {
    unoptimized: true,     // Required for static export
  },
};

export default nextConfig;
```

## Step 4: Build and Deploy Your App

### Option A: Using the Deploy Script (Automatic)
```bash
# One command to build, upload, and invalidate cache
chmod +x deploy.sh
./deploy.sh
```

### Option B: Using Make (Simple)
```bash
make deploy
```

### Option C: Manual Steps
```bash
# 1. Build the Next.js app
npm run build

# 2. Upload to S3
aws s3 sync ./out s3://$(cd terraform && terraform output -raw s3_bucket_name)/ \
  --delete --cache-control 'public, max-age=3600' --region us-east-1

# 3. Invalidate CloudFront cache
aws cloudfront create-invalidation \
  --distribution-id $(cd terraform && terraform output -raw cloudfront_distribution_id) \
  --paths "/*" --region us-east-1
```

## Step 5: Access Your Application

Your app is now live at:
```bash
make url
# or
echo "https://$(cd terraform && terraform output -raw domain_name)"
```

Visit `https://app-dev.zamait.in` in your browser!

## Common Commands

```bash
# See all Terraform outputs
make outputs

# View your application URL
make url

# Redeploy after code changes
make deploy

# Just invalidate CloudFront cache
make invalidate

# Clean build artifacts
make clean

# View infrastructure costs (plan only)
make plan

# Destroy everything (be careful!)
make destroy
```

## File Structure

```
├── terraform/                    # Infrastructure as code
│   ├── main.tf                  # Main configuration
│   ├── s3.tf                    # S3 bucket setup
│   ├── cloudfront.tf            # CDN configuration
│   ├── route53.tf               # DNS configuration
│   ├── variables.tf             # Input variables
│   ├── outputs.tf               # Outputs
│   ├── cloudfront-function.js   # URL rewriting function
│   ├── terraform.tfvars         # Your configuration (git ignored)
│   └── README.md                # Detailed documentation
├── deploy.sh                     # Automated deployment script
├── Makefile                      # Command shortcuts
├── next.config.ts               # Next.js configuration
└── out/                          # Built static files (gitignored)
```

## Cache Strategy

- **HTML files**: 1 hour cache
- **JavaScript/CSS (_next/*)**: 1 year (immutable, hashed filenames)
- **Images/Media**: 24 hours
- **CloudFront**: Global edge locations

## Updating Your App

Every time you update your code:

```bash
# Option 1: Automatic (recommended)
make deploy

# Option 2: Manual
npm run build
aws s3 sync ./out s3://your-bucket/ --delete --region us-east-1
aws cloudfront create-invalidation --distribution-id YOUR-ID --paths "/*" --region us-east-1
```

## Troubleshooting

### 403 Forbidden Errors
```bash
# Verify bucket policy is correct
aws s3api get-bucket-policy --bucket app-dev-us-east-1

# Check CloudFront Origin Access Control
aws cloudfront get-distribution --id YOUR-DISTRIB-ID
```

### DNS Not Working
```bash
# Verify Route53 records
aws route53 list-resource-record-sets --hosted-zone-id YOUR-ZONE-ID

# Check propagation (might take up to 48 hours)
nslookup app-dev.zamait.in
```

### CloudFront Cache Issues
```bash
# Create invalidation
aws cloudfront create-invalidation --distribution-id YOUR-ID --paths "/*" --region us-east-1

# Check status
aws cloudfront list-invalidations --distribution-id YOUR-ID --region us-east-1
```

### Certificate Errors
```bash
# Verify certificate exists in us-east-1
aws acm list-certificates --region us-east-1 | grep zamait.in

# Status should be "ISSUED"
```

## Costs

Typical monthly costs (rough estimates):
- **S3 Storage**: $0.50-2 (depends on size)
- **CloudFront**: $20-100 (depends on traffic)
- **Route53**: $0.50 (zone) + queries
- **Total**: ~$21-103/month for small to medium traffic

Reduce costs by:
- Using `PriceClass_100` for CloudFront (default)
- Enabling compression (already configured)
- Proper cache headers (already configured)

## Next Steps

1. ✅ Deploy infrastructure with `make apply`
2. ✅ Deploy application with `make deploy`
3. Visit `https://app-dev.zamait.in`
4. Set up CI/CD for automatic deployments
5. Configure monitoring/logging

## Getting Help

For detailed information:
- See `terraform/README.md` for complete Terraform documentation
- Check AWS documentation: https://docs.aws.amazon.com/cloudfront/
- Next.js static export: https://nextjs.org/docs/app/building-your-application/deploying/static-exports

## Important Notes

⚠️ **Before Destroying Infrastructure**:
```bash
# Delete S3 contents first (Terraform won't delete non-empty buckets)
aws s3 rm s3://app-dev-us-east-1/ --recursive

# Then destroy
make destroy
```

📝 **Backups**:
- S3 versioning is enabled
- Keep backups of `terraform.tfstate` (or use remote state backend)
- Test changes in a dev environment first

🔐 **Security**:
- S3 bucket is private (not public)
- CloudFront uses OAC (Origin Access Control)
- TLS/SSL with ACM certificate
- All traffic forced to HTTPS

Happy deploying! 🚀
