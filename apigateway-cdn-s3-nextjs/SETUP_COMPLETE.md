# Terraform & Deployment Setup Complete! 🚀

## Summary of Created Files

Your complete infrastructure-as-code setup for deploying a Next.js application on AWS S3 + CloudFront CDN is now ready!

### 📁 Terraform Infrastructure (`/terraform/`)

| File | Purpose |
|------|---------|
| `main.tf` | Provider configuration, locals, and terraform setup |
| `variables.tf` | All input variables with descriptions and defaults |
| `outputs.tf` | Output values for easy reference after deployment |
| `s3.tf` | S3 bucket configuration with security, encryption, versioning |
| `cloudfront.tf` | CloudFront distribution, cache policies, and functions |
| `route53.tf` | DNS record creation for app-dev.zamait.in |
| `cloudfront-function.js` | URL rewriting logic for SPA routing |
| `terraform.tfvars.example` | Example configuration file (copy this!) |
| `README.md` | Comprehensive Terraform documentation |
| `.gitignore` | Git ignore rules for Terraform files |

### 📄 Deployment Automation

| File | Purpose |
|------|---------|
| `deploy.sh` | Automated deployment script (build → upload → invalidate) |
| `Makefile` | Command shortcuts for common tasks |
| `.github/workflows/deploy.yml` | GitHub Actions CI/CD pipeline |

### 📖 Documentation

| File | Purpose |
|------|---------|
| `QUICKSTART.md` | 5-minute quick start guide |
| `ARCHITECTURE.md` | Detailed architecture diagrams and explanations |

## 🎯 Architecture Overview

```
Users
  ↓
Route53 (DNS)
  ↓
CloudFront CDN (TLS/SSL with *.zamait.in certificate)
  ↓
S3 Bucket (Private, encrypted storage)
```

**Key Features:**
- ✅ Global CDN with CloudFront edge locations
- ✅ TLS/SSL encryption with ACM certificate
- ✅ Intelligent caching (1 hour for HTML, 1 year for assets)
- ✅ SPA routing with CloudFront Functions
- ✅ S3 versioning for rollback capability
- ✅ Private bucket with Origin Access Control
- ✅ Gzip/Brotli compression enabled
- ✅ Automatic cache invalidation on deploy

## 🚀 Quick Start (5 Minutes)

### 1. Prerequisites
```bash
# Ensure you have:
- AWS Account with S3, CloudFront, Route53, ACM access
- AWS CLI configured: `aws configure`
- Terraform: `brew install terraform` (Mac) or follow terraform.io
- Node.js v18+
- ACM Certificate for *.zamait.in in us-east-1
- Route53 hosted zone for zamait.in
```

### 2. Configure Terraform
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars and set route53_zone_id
```

### 3. Deploy Infrastructure
```bash
make init    # Initialize Terraform
make plan    # Review changes
make apply   # Deploy (type 'yes' to confirm)
```

### 4. Deploy Application
```bash
# One command does everything:
make deploy

# Or individual commands:
npm run build              # Build Next.js
make upload               # Upload to S3
make invalidate           # Clear CloudFront cache
```

### 5. Access Your App
```bash
make url
# Then visit: https://app-dev.zamait.in
```

## 📋 What Each File Does

### Terraform Files

**main.tf**
- Configures AWS provider for us-east-1 (required for CloudFront)
- Sets up terraform backend (optional remote state)
- Defines local variables for resource naming
- Adds common tags for all resources

**variables.tf**
- Defines 12 input variables
- All variables have defaults (only route53_zone_id is required)
- Allows easy customization without editing main files

**s3.tf**
- Creates private S3 bucket with encryption
- Enables versioning for disaster recovery
- Configures CORS for the application domain
- Sets up server-side encryption (AES256)
- Blocks all public access (CloudFront uses OAC)
- Creates Origin Access Control for secure CloudFront access

**cloudfront.tf**
- Creates CloudFront distribution
- Configures multiple cache behaviors:
  - HTML: 1 hour cache (user-facing content)
  - /_next/*: 24 hours (static assets with hashes)
- Attaches custom function for URL rewriting
- Associates ACM certificate
- Configures compression (gzip + brotli)
- Sets up custom error responses

**route53.tf**
- Creates A and AAAA (IPv6) records
- Points app-dev.zamait.in to CloudFront
- Uses alias record (no additional charges)
- Enables health checks (optional enhancement)

**outputs.tf**
- Displays critical information after deployment
- Provides deployment commands
- Shows application URL
- Supplies S3 bucket name and CloudFront ID

### Deployment Files

**deploy.sh** (Bash Script)
- Prerequisites: Checks Terraform, AWS CLI, Node.js, npm
- Build: Runs `npm run build` to create static files
- Verify: Gets S3 bucket and CloudFront ID from Terraform
- Upload: Intelligently uploads with correct cache headers:
  - HTML: 1 hour cache
  - _next/* assets: 1 year immutable cache
  - Other files: 24 hour cache
- Invalidate: Creates CloudFront invalidation and waits for completion
- Clean exit: Displays summary with app URL

**Makefile**
- `make init` → terraform init
- `make plan` → terraform plan
- `make apply` → terraform apply
- `make deploy` → build + upload + invalidate
- `make build` → npm run build
- `make upload` → sync to S3
- `make invalidate` → clear CloudFront cache
- `make outputs` → show terraform outputs
- `make destroy` → remove all resources

**.github/workflows/deploy.yml**
- GitHub Actions CI/CD pipeline
- Triggered on: push to main, pull requests, manual trigger
- Steps:
  1. Validate Terraform configuration
  2. Build Next.js application
  3. Run tests (if available)
  4. Upload to S3 with intelligent caching
  5. Invalidate CloudFront cache
  6. Optional performance test with Lighthouse

### Documentation Files

**QUICKSTART.md**
- Step-by-step setup in 5 minutes
- Prerequisites checklist
- Configuration instructions
- Common commands
- Troubleshooting guide
- Cost estimates

**ARCHITECTURE.md**
- ASCII art diagrams of the architecture
- Request flow visualization
- Data flow during deployment
- CloudFront caching strategy
- DNS resolution process
- TLS/SSL certificate chain
- Performance optimization details

## 🔧 Configuration Details

### Domain Setup
- **DNS**: app-dev.zamait.in
- **Certificate**: *.zamait.in (wildcard, already in ACM)
- **Hosted Zone**: zamait.in (must pre-exist in Route53)

### CloudFront Cache Strategy
```
HTML Files: 3600 seconds (1 hour)
  - Query strings: forwarded (for debugging)
  - Headers: Accept
  - Compress: yes
  
Static Assets (_next/*): 86400 seconds (24 hours)
  - Query strings: NOT forwarded (have content hashes)
  - Compress: yes
  - File types: .js, .css, .woff, .woff2
```

### S3 Security
```
✓ All public access blocked
✓ Encryption at rest (AES256)
✓ Origin Access Control only (no public URLs)
✓ Versioning enabled
✓ Access logging enabled
✓ CORS configured for domain only
```

## 📊 Cost Breakdown

**Monthly estimates:**
- **S3 Storage**: $0.50-2 (depends on size)
- **S3 Requests**: $0.10-0.50
- **CloudFront Data Transfer**: $20-100 (depends on traffic)
- **Route53**: $0.50 zone + queries
- **Total**: ~$21-103/month for small to medium traffic

**Cost optimization:**
- Use `PriceClass_100` for CloudFront (default)
- Compression enabled (saves bandwidth)
- Smart caching reduces origin load
- S3 versioning minimal cost

## 🔐 Security Features

✅ **HTTPS/TLS**: Enforced with ACM certificate
✅ **Origin Access Control**: S3 bucket only accessible via CloudFront
✅ **Private S3**: No public URLs exposed
✅ **Encryption**: All data encrypted at rest
✅ **Versioning**: Full history for recovery
✅ **Logging**: Access logs for auditing
✅ **DDoS Protection**: CloudFront includes AWS Shield

## 📞 Common Tasks

### Deploy a new version:
```bash
make deploy
```

### Invalidate CloudFront cache:
```bash
make invalidate
```

### View deployment status:
```bash
make outputs
```

### Destroy all resources:
```bash
make destroy
```

### View application logs:
```bash
make logs
```

## ⚠️ Important Notes

1. **AWS Credentials**: Required, stored in ~/.aws/credentials
2. **Certificate Region**: Must be in us-east-1 for CloudFront
3. **S3 Deletion**: Terraform won't delete non-empty buckets
   ```bash
   aws s3 rm s3://your-bucket/ --recursive
   ```
4. **DNS Propagation**: May take up to 48 hours
5. **CloudFront Invalidation**: Up to 5 minutes to propagate
6. **Next.js Config**: Must have `output: export` for static build

## 🆘 Troubleshooting

### 403 Forbidden from S3
- Verify CloudFront has Origin Access Control
- Check S3 bucket policy is correctly configured
- Ensure files are actually uploaded to S3

### DNS not resolving
- Verify Route53 zone ID is correct
- Check nameservers are set in registrar
- Wait 48 hours for propagation

### Certificate errors
- Verify certificate exists in us-east-1 (required!)
- Check certificate domain is *.zamait.in
- Ensure certificate status is "ISSUED"

### Slow performance
- Check CloudFront cache hit ratio
- Verify compression is enabled
- Review cache TTL settings

## 📚 Additional Resources

- [AWS CloudFront Documentation](https://docs.aws.amazon.com/cloudfront/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Next.js Static Export](https://nextjs.org/docs/app/building-your-application/deploying/static-exports)
- [CloudFront Functions](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/cloudfront-functions.html)

## 🎓 Learning Path

1. **Understand the setup**: Read QUICKSTART.md
2. **Study architecture**: Review ARCHITECTURE.md
3. **Deploy infrastructure**: `make apply`
4. **Deploy app**: `make deploy`
5. **Monitor performance**: Use AWS Console
6. **Optimize caching**: Adjust TTL values as needed
7. **Setup CI/CD**: Enable GitHub Actions workflow
8. **Scale up**: Configure additional CloudFront behaviors

## ✨ Next Steps

1. ✅ Review QUICKSTART.md
2. ✅ Copy terraform.tfvars.example → terraform.tfvars
3. ✅ Get Route53 zone ID
4. ✅ Run `make init && make apply`
5. ✅ Run `make deploy`
6. ✅ Visit https://app-dev.zamait.in
7. ✅ Setup GitHub Actions for continuous deployment
8. ✅ Monitor with CloudWatch

---

**Created on**: 20 March 2026
**Terraform Version**: 1.0+
**AWS Services**: S3, CloudFront, Route53, ACM, CloudWatch
**Next.js Version**: 13+ (with App Router)

Good luck with your deployment! 🚀
