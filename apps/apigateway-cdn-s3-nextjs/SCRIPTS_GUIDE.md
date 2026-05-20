# Setup & Deploy Scripts Guide

Two comprehensive shell scripts for deploying Next.js to S3 + CloudFront.

## Scripts Overview

### `setup.sh` - Infrastructure Setup
Creates AWS infrastructure (one-time setup)

### `deploy.sh` - Application Deployment  
Builds and uploads your Next.js app to S3 (run each deployment)

---

## Quick Start

### 1️⃣ First Time: Setup Infrastructure

```bash
# Configure variables
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars - set route53_zone_id

# Run setup
cd ..
./setup.sh
```

**What it does:**
- ✓ Verifies AWS prerequisites
- ✓ Checks ACM certificate exists
- ✓ Initializes Terraform
- ✓ Shows deployment plan
- ✓ Creates infrastructure
- ✓ Verifies deployment

**Time:** ~15-25 minutes (mostly waiting for CloudFront)

### 2️⃣ Every Deploy: Upload Application

```bash
./deploy.sh
```

**What it does:**
- ✓ Builds Next.js app
- ✓ Uploads files to S3 with smart caching
- ✓ Invalidates CloudFront cache
- ✓ Shows deployment status

**Time:** ~2-5 minutes

---

## `setup.sh` - Detailed Guide

### Usage

```bash
./setup.sh
```

No arguments needed - it's interactive!

### What It Does

1. **Checks Prerequisites** (2 min)
   - Terraform installed ✓
   - AWS CLI installed ✓
   - AWS credentials configured ✓
   - Shows your AWS account

2. **Verifies AWS Resources** (2 min)
   - Reads `terraform/terraform.tfvars`
   - Checks Route53 zone exists
   - Verifies ACM certificate
   - Must be in us-east-1, status: ISSUED

3. **Initializes Terraform** (1 min)
   - `terraform init`
   - Downloads AWS provider
   - Creates `.terraform/` directory

4. **Validates Configuration** (1 min)
   - `terraform validate`
   - Checks for syntax errors
   - Verifies formatting

5. **Shows Plan** (2 min)
   - `terraform plan`
   - Lists resources to create
   - Shows no resources will be destroyed

6. **Applies Configuration** (Interactive)
   - Shows plan output
   - Prompts: "Do you want to apply these changes?"
   - Type: `yes` to confirm
   - Creates infrastructure (~15-20 min total)

7. **Verifies Deployment** (2 min)
   - Checks S3 bucket created
   - Checks CloudFront distribution
   - Verifies Route53 records

8. **Shows Next Steps**
   - Displays commands to build and deploy
   - Links to documentation

### Example Output

```
════════════════════════════════════════════════════════════
Next.js S3 + CloudFront Infrastructure Setup
════════════════════════════════════════════════════════════

[1/7] Checking Prerequisites
✓ Terraform installed: 1.5.7
✓ AWS CLI installed
✓ AWS credentials configured
ℹ AWS Account: 088862082874

[2/7] Verifying AWS Resources
✓ terraform.tfvars found
✓ Route53 Zone ID configured: Z1234567890ABC
✓ Route53 zone verified
✓ ACM certificate verified: arn:aws:acm:us-east-1:...
  Certificate Status: ISSUED

[3/7] Initializing Terraform
→ Running terraform init...
✓ Terraform initialized

[4/7] Validating Terraform Configuration
→ Running terraform validate...
✓ Terraform configuration valid

→ Running terraform fmt check...
✓ Terraform formatting correct

[5/7] Terraform Plan
→ Generating terraform plan...
✓ Terraform plan generated
ℹ Resources to create: multiple
  • S3 Bucket (private, encrypted, versioned)
  • CloudFront Distribution (global CDN)
  • Route53 DNS Records (A and AAAA)
  • CloudFront Cache Policies
  • CloudFront Functions (URL rewriting)

Do you want to apply these changes? (yes/no): yes

→ Applying terraform configuration...
✓ Infrastructure deployed successfully!

[6/7] Verifying Infrastructure
→ Verifying S3 bucket...
✓ S3 bucket created: app-dev-us-east-1

→ Verifying CloudFront distribution...
✓ CloudFront distribution created: E1A2B3C4D5E6F7G
  Status: InProgress (may show 'InProgress' - will complete in 15-20 minutes)

→ Verifying Route53 records...
✓ Route53 records created

[7/7] Setup Complete! ✓

Next Steps:
1. Wait for CloudFront deployment (15-20 minutes)
2. Build your Next.js application:
   npm run build
3. Deploy to S3:
   ./deploy.sh
4. Access your application:
   https://app-dev.zamait.in
```

### Troubleshooting Setup

**❌ "Terraform is not installed"**
```bash
# Install Terraform
brew install terraform  # macOS
# or from https://www.terraform.io/downloads
```

**❌ "AWS credentials not configured"**
```bash
aws configure
# Enter: AWS Access Key ID
# Enter: AWS Secret Access Key
# Enter: Default region (us-east-1)
# Enter: Output format (json)
```

**❌ "Route53 Zone ID not configured"**
```bash
# Find your zone ID
aws route53 list-hosted-zones-by-name --dns-name zamait.in
# Edit terraform/terraform.tfvars:
route53_zone_id = "Z1234567890ABC"
```

**❌ "No ACM certificate found"**
- Go to AWS Console → Certificate Manager
- Make sure you're in **us-east-1**
- Create new certificate for `*.zamait.in`
- Verify domain ownership
- Wait for status "ISSUED"

---

## `deploy.sh` - Detailed Guide

### Usage

```bash
# Build and deploy (default)
./deploy.sh

# Deploy without rebuilding existing ./out/
./deploy.sh --skip-build

# Show help
./deploy.sh --help
```

### What It Does

1. **Checks Prerequisites** (30 sec)
   - AWS CLI installed ✓
   - AWS credentials configured ✓

2. **Builds Next.js App** (1-2 min)
   - Installs npm dependencies (if needed)
   - Runs: `npm run build`
   - Creates: `./out/` directory
   - Shows: file count & build size

3. **Gets Infrastructure Details** (30 sec)
   - Reads from Terraform outputs
   - S3 bucket name
   - CloudFront distribution ID
   - AWS region (always us-east-1)

4. **Uploads to S3 with Smart Caching** (1-3 min)
   - HTML files: 1 hour cache
   - JavaScript/CSS/_next/*: 1 year immutable cache
   - Images/Assets: 24 hour cache
   - Shows upload progress

5. **Invalidates CloudFront Cache** (1-2 min)
   - Creates invalidation for `/*`
   - Waits up to 5 minutes for completion
   - Shows status updates

6. **Shows Deployment Summary**
   - Application URL
   - S3 bucket name
   - CloudFront distribution ID
   - Useful commands

### Cache Strategy

| File Type | Cache Duration | Purpose |
|-----------|---|---|
| `*.html` | 1 hour | User-facing content (updated frequently) |
| `_next/*.js` | 1 year | Static assets with content hashes |
| `_next/*.css` | 1 year | Static assets with content hashes |
| `*.woff*` | 1 year | Font files (rarely change) |
| `*.png, *.jpg` | 24 hours | Images (medium change frequency) |
| `*.json` | 24 hours | Data files |

### Example Output

```
╔════════════════════════════════════════════════════════════╗
║   Next.js Application Deployment to S3 + CloudFront        ║
╚════════════════════════════════════════════════════════════╝

════════════════════════════════════════════════════════════
[1/5] Checking Prerequisites
════════════════════════════════════════════════════════════

✓ AWS CLI installed

✓ AWS credentials configured

════════════════════════════════════════════════════════════
[2/5] Building Next.js Application
════════════════════════════════════════════════════════════

→ Installing dependencies...
✓ Dependencies installed

→ Building Next.js application...
✓ Next.js application built successfully
ℹ Files: 245 | Size: 3.2M

════════════════════════════════════════════════════════════
[3/5] Retrieving Infrastructure Details
════════════════════════════════════════════════════════════

→ Getting S3 bucket name...
✓ S3 Bucket: app-dev-us-east-1

→ Getting CloudFront distribution ID...
✓ CloudFront Distribution: E1A2B3C4D5E6F7G

✓ AWS Region: us-east-1

════════════════════════════════════════════════════════════
[4/5] Uploading to S3
════════════════════════════════════════════════════════════

ℹ Target bucket: s3://app-dev-us-east-1

ℹ Uploading with intelligent cache headers...

→ 1. HTML files (1 hour cache)...
   Uploaded 12 files
→ 2. Images (24 hour cache)...
   Uploaded 15 files
   Uploaded JavaScript files
   Uploaded CSS files
   Uploaded font files

✓ All files uploaded to S3

════════════════════════════════════════════════════════════
[5/5] Invalidating CloudFront Cache
════════════════════════════════════════════════════════════

ℹ Creating invalidation for distribution: E1A2B3C4D5E6F7G

✓ Invalidation created: I1A2B3C4D5E6F7G

→ Waiting for invalidation to complete...
   Status: Completed (300 seconds)...
✓ Invalidation completed

════════════════════════════════════════════════════════════
[6/5] Deployment Complete! ✓
════════════════════════════════════════════════════════════

Deployment Details:

Application URL:
  https://app-dev.zamait.in

Infrastructure:
  S3 Bucket: app-dev-us-east-1
  CloudFront: E1A2B3C4D5E6F7G

Next steps:
  1. Wait 1-2 minutes for cache invalidation to fully propagate
  2. Open: https://app-dev.zamait.in
  3. Verify all assets load correctly
  4. Clear browser cache if needed (Ctrl+Shift+Delete)

Useful commands:
  • ./deploy.sh --skip-build   - Deploy without rebuilding
  • make invalidate            - Manually invalidate cache
  • make url                   - Show application URL
  • make outputs               - Show infrastructure details

═══════════════════════════════════════════════════════════
Deployment succeeded! 🚀
═══════════════════════════════════════════════════════════
```

### Using `--skip-build` Flag

When you only change static files or don't need to rebuild:

```bash
# Manual scenario
npm run build
./deploy.sh --skip-build

# Faster deployments when you know build is current
./deploy.sh --skip-build
```

### Troubleshooting Deploy

**❌ "AWS credentials not configured"**
```bash
aws configure
aws sts get-caller-identity  # Verify it works
```

**❌ "Could not retrieve S3 bucket name"**
- Run setup.sh first: `./setup.sh`
- Or verify Terraform outputs: `cd terraform && terraform output`

**❌ "Build fails with 'output: export not configured'"**
- Update `next.config.ts`:
```typescript
output: 'export',
trailingSlash: true,
images: { unoptimized: true }
```

**❌ "Deploy works but site shows 404"**
1. Wait 1-2 minutes for invalidation
2. Clear browser cache (Ctrl+Shift+Delete)
3. Hard refresh (Ctrl+Shift+R on Linux/Windows or Cmd+Shift+R on Mac)

---

## Complete Workflow

### First Time (Setup)
```bash
# 1. Configure
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit: set route53_zone_id

cd ..

# 2. Setup infrastructure
./setup.sh
# Type: yes when prompted
# Wait: 15-20 minutes

# 3. Verify CloudFront deployed
cd terraform
terraform output cloudfront_distribution_id
# Check status is "Deployed"
```

### Every Deploy (Update)
```bash
# 1. Make code changes
# 2. Deploy
./deploy.sh

# 3. Verify
# Visit: https://app-dev.zamait.in
```

### For Quick Iterations
```bash
# When you only changed static files
npm run build
./deploy.sh --skip-build
```

---

## Environment Variables

No environment variables needed - scripts read from:
- `terraform/terraform.tfvars` (infrastructure config)
- Terraform outputs (bucket name, distribution ID)
- AWS credentials from `~/.aws/credentials`

---

## Performance Tips

### Faster Setup
- Pre-create ACM certificate before running setup.sh
- Pre-verify nameservers are set in registrar

### Faster Deploys
- Use `--skip-build` when build is current
- CloudFront invalidation happens in background
- Don't wait for full completion if in hurry

### Faster Builds
- Use npm workspaces to cache dependencies
- Use Turbo for monorepos
- Optimize images before committing

---

## Security Notes

✅ **Scripts are secure:**
- ✓ No credentials stored in scripts
- ✓ Uses AWS CLI from system credentials
- ✓ terraform.tfvars added to .gitignore
- ✓ No passwords printed to console

⚠️ **Be careful with:**
- ✓ Keep AWS credentials private
- ✓ Don't commit terraform.tfvars
- ✓ Don't share terraform.tfstate

---

## Combining with CI/CD

These scripts work great with GitHub Actions:

```yaml
name: Deploy
on: [push]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
      - name: Deploy
        run: ./deploy.sh
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
```

---

## Common Commands Reference

```bash
# Setup once
./setup.sh

# Deploy (normal)
./deploy.sh

# Deploy (skip build)
./deploy.sh --skip-build

# Using Makefile instead
make deploy          # Full deploy
make build           # Just build
make upload          # Just upload
make invalidate      # Just invalidate cache

# Manual operations
cd terraform
terraform plan       # Preview changes
terraform destroy    # Delete infrastructure
terraform output     # Show details

# AWS CLI direct access
aws s3 ls                                    # List buckets
aws cloudfront list-distributions            # List distributions
aws route53 list-hosted-zones                # List zones
```

---

## Documentation Links

- **Quick Start**: See [QUICKSTART.md](QUICKSTART.md)
- **Architecture**: See [ARCHITECTURE.md](ARCHITECTURE.md)
- **Troubleshooting**: See [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- **Checklist**: See [DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md)
- **Terraform Docs**: See [terraform/README.md](terraform/README.md)

---

## Support

**If setup.sh fails:**
1. Check [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for solutions
2. Review AWS Console for errors
3. Verify prerequisites are installed

**If deploy.sh fails:**
1. Try: `./deploy.sh --skip-build`
2. Check AWS credentials: `aws sts get-caller-identity`
3. Verify S3 bucket exists: `aws s3 ls`

---

**Last Updated**: 20 March 2026

Happy deploying! 🚀
