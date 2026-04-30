# Pre-Deployment Checklist

Complete this checklist before deploying your Next.js application to S3 + CloudFront.

## ✅ Prerequisites

### AWS Account Requirements
- [ ] AWS Account created and active
- [ ] Billing enabled
- [ ] IAM user with permissions:
  - S3: CreateBucket, GetObject, PutObject, PutBucketPolicy, GetBucketPolicy
  - CloudFront: CreateDistribution, GetDistribution, CreateInvalidation
  - Route53: ListHostedZones, ChangeResourceRecordSets
  - ACM: ListCertificates, GetCertificate
  - IAM: GetRole, CreateRole (for Lambda if needed)

### AWS Resources (Pre-existing)
- [ ] ACM Certificate created for `*.zamait.in` in **us-east-1** region
  - Certificate status: **ISSUED**
  - Region: **us-east-1** (required for CloudFront - do NOT use other regions!)
  - Verification: `aws acm list-certificates --region us-east-1 | grep zamait.in`

- [ ] Route53 Hosted Zone for `zamait.in` created
  - Zone ID noted (you'll need this!)
  - Nameservers set in your registrar
  - Verification: `aws route53 list-hosted-zones | grep zamait.in`

### Local Setup
- [ ] AWS CLI installed: `aws --version`
- [ ] AWS credentials configured: `aws configure`
  - Test: `aws sts get-caller-identity`
- [ ] Terraform installed (v1.0+): `terraform --version`
- [ ] Node.js installed (v18+): `node --version`
- [ ] npm installed: `npm --version`
- [ ] Git installed: `git --version`
- [ ] Git configured: `git config --list | grep user`

### Network
- [ ] Internet connection stable
- [ ] No corporate firewall blocking AWS APIs
- [ ] SSH key configured (if using GitHub Actions)

## 📋 Configuration

### Next.js Configuration
- [ ] `next.config.ts` has these settings:
  ```typescript
  {
    output: 'export',
    trailingSlash: true,
    images: { unoptimized: true }
  }
  ```
- [ ] No dynamic routes that depend on backend endpoints
- [ ] No API routes (unless using Lambda@Edge)
- [ ] All external APIs are accessible from browser
- [ ] No environment variables used for static secrets

### Terraform Configuration
- [ ] Copied `terraform/terraform.tfvars.example` to `terraform/terraform.tfvars`
- [ ] Updated `route53_zone_id` with your hosted zone ID:
  ```bash
  aws route53 list-hosted-zones-by-name --dns-name zamait.in
  ```
- [ ] Verified all other variables in `terraform.tfvars`:
  - [ ] `aws_region`: us-east-1 (don't change!)
  - [ ] `environment`: dev (or your environment)
  - [ ] `project_name`: app (or your project name)
  - [ ] `domain_name`: app-dev.zamait.in
  - [ ] `certificate_domain`: *.zamait.in
  - [ ] `cloudfront_price_class`: PriceClass_100 (default)
  - [ ] `s3_bucket_versioning`: true (recommended)

### Deployment Scripts
- [ ] Made deploy.sh executable:
  ```bash
  chmod +x deploy.sh
  ```
- [ ] Verified Makefile exists: `test -f Makefile && echo "OK"`

## 🔒 Security Verification

- [ ] AWS credentials are in local credential file, NOT in code
- [ ] `.gitignore` includes:
  - `terraform/terraform.tfvars`
  - `.terraform/`
  - `*.tfstate`
  - `.env`
- [ ] terraform.tfvars file is NOT committed to Git
- [ ] No sensitive data in code (secrets, API keys, etc.)
- [ ] S3 bucket is NOT publicly accessible
- [ ] CloudFront Origin Access Control is enabled
- [ ] HTTPS is enforced (no HTTP access)

## 🧪 Pre-Flight Tests

### Local Build Test
```bash
cd /path/to/project
npm install
npm run build
# Should create ./out directory without errors
```
- [ ] Build completes without errors
- [ ] `out/` directory created
- [ ] `out/index.html` exists
- [ ] `out/_next/` directory exists
- [ ] Build size is reasonable (< 500MB typical)

### Terraform Validation
```bash
cd terraform
terraform init
terraform validate
terraform fmt -check
```
- [ ] terraform init succeeds
- [ ] terraform validate passes
- [ ] terraform fmt shows no formatting issues

### Terraform Plan
```bash
terraform plan -out=tfplan
```
- [ ] Plan shows resources to be created (should see: S3, CloudFront, Route53, etc.)
- [ ] No errors in the plan
- [ ] Number of resources to create is reasonable (should be ~10-15)
- [ ] All variable values are correct

### AWS Credentials Test
```bash
aws sts get-caller-identity
```
- [ ] Returns your AWS Account ID
- [ ] Returns your IAM User
- [ ] Don't see "Access Denied" message

### CloudFront Function Test
```bash
test -f terraform/cloudfront-function.js && echo "CloudFront function found"
cat terraform/cloudfront-function.js | head -5
```
- [ ] CloudFront function file exists
- [ ] File is not empty

## 🚀 Deployment Checklist

### Step 1: Initialize Infrastructure
```bash
cd terraform
terraform init
```
- [ ] Initialization completes
- [ ] `.terraform/` directory created
- [ ] `.terraform.lock.hcl` created

### Step 2: Apply Terraform
```bash
make apply
# or
terraform apply tfplan
```
- [ ] Review the plan output
- [ ] All resources shown are expected
- [ ] Type "yes" to confirm
- [ ] [ ] Wait for "Apply complete!" message
- [ ] Terraform outputs are displayed
- [ ] No errors in output

### Step 3: Verify Infrastructure
```bash
# Check S3 bucket
aws s3 ls | grep app-dev

# Check CloudFront
aws cloudfront list-distributions

# Check Route53
aws route53 list-resource-record-sets --hosted-zone-id YOUR-ZONE-ID
```
- [ ] S3 bucket created
- [ ] CloudFront distribution created (may take 15-20 minutes)
- [ ] Route53 records created

### Step 4: Build Application
```bash
npm run build
```
- [ ] Build completes without errors
- [ ] `out/` directory exists
- [ ] No build warnings that concern you

### Step 5: Deploy Application
```bash
make deploy
# or
./deploy.sh
```
- [ ] All HTML files uploaded successfully
- [ ] All `_next/*` files uploaded successfully
- [ ] All other files uploaded successfully
- [ ] CloudFront invalidation created
- [ ] Invalidation status: Completed (or In Progress)

### Step 6: Verify Deployment
```bash
# Get your app URL
make url

# Test DNS resolution
nslookup app-dev.zamait.in

# Test HTTPS connectivity
curl -I https://app-dev.zamait.in

# Test page load
curl https://app-dev.zamait.in | head -20
```
- [ ] DNS resolves to CloudFront domain
- [ ] HTTPS connection successful
- [ ] Status code is 200 OK
- [ ] HTML content returned

## 🌐 DNS Verification

### Propagation
- [ ] DNS propagation might take up to 48 hours
- [ ] After 15-30 minutes of waiting:
  ```bash
  dig app-dev.zamait.in
  dig app-dev.zamait.in +short
  ```
- [ ] Should show CloudFront domain name

### Certificate Verification
- [ ] Browser shows green HTTPS lock 🔒
- [ ] Certificate name shows `*.zamait.in`
- [ ] Certificate is valid (not expired)
- [ ] No certificate warnings

### Access Test
- [ ] Open `https://app-dev.zamait.in` in browser
- [ ] Verify page loads correctly
- [ ] Check console for any errors
- [ ] Verify all assets load (CSS, JS, images)
- [ ] Test responsive design
- [ ] Verify dynamic features work

## 📊 Performance Verification

```bash
# Check cache headers
curl -I https://app-dev.zamait.in

# Check CloudFront metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/CloudFront \
  --metric-name Requests \
  --dimensions Name=DistributionId,Value=YOUR-DISTRIB-ID \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-01T12:00:00Z \
  --period 3600 \
  --statistics Sum
```
- [ ] Cache-Control headers correct:
  - HTML: `public, max-age=3600`
  - _next/*: `public, max-age=31536000, immutable`
- [ ] CloudFront is receiving requests
- [ ] No 5xx errors
- [ ] Cache hit ratio is good (> 80% for repeat requests)

## 🔄 Continuous Deployment (Optional)

If using GitHub Actions:

- [ ] GitHub repository configured
- [ ] Branch protection rules set:
  - [ ] Require reviews (at least 1)
  - [ ] Require status checks to pass
- [ ] GitHub Secrets configured:
  - [ ] `AWS_ACCESS_KEY_ID`
  - [ ] `AWS_SECRET_ACCESS_KEY`
  - [ ] `SLACK_WEBHOOK` (optional)
- [ ] Workflow file exists: `.github/workflows/deploy.yml`
- [ ] Workflow is enabled
- [ ] Test deployment via git push:
  ```bash
  git add .
  git commit -m "test deployment"
  git push origin main
  ```
- [ ] GitHub Actions workflow runs successfully
- [ ] Application updates on github.com/repo/actions

## 📝 Documentation

- [ ] README.md updated with deployment instructions
- [ ] Team has access to QUICKSTART.md
- [ ] Team has access to ARCHITECTURE.md
- [ ] SETUP_COMPLETE.md is bookmarked
- [ ] Runbook created for team
- [ ] Team knows how to rollback if needed

## 🎯 Post-Deployment

### Monitoring
- [ ] CloudWatch alarms configured (optional):
  ```bash
  # Create alarm for 4xx errors
  aws cloudwatch put-metric-alarm \
    --alarm-name cloudfront-4xx \
    --alarm-description "Alert on 4xx errors" \
    --metric-name 4xxErrorRate \
    --namespace AWS/CloudFront
  ```
- [ ] CloudFront distribution is being monitored
- [ ] S3 bucket metrics enabled

### Backup & Recovery
- [ ] S3 versioning is enabled
- [ ] Understand rollback procedure
- [ ] Team knows to contact AWS support if issues occur
- [ ] Have backup of terraform.tfstate file

### Documentation & Knowledge Transfer
- [ ] Team trained on deployment process
- [ ] Team knows emergency contacts
- [ ] Cost tracking configured (AWS Cost Explorer)
- [ ] Budget alerts set up

## 🚨 Troubleshooting

If something goes wrong:

1. **Check Terraform state**:
   ```bash
   terraform state list
   terraform state show aws_s3_bucket.app_bucket
   ```

2. **View CloudFront distribution status**:
   ```bash
   aws cloudfront get-distribution-config --id YOUR-DISTRIB-ID
   ```

3. **Check S3 bucket policies**:
   ```bash
   aws s3api get-bucket-policy --bucket your-bucket-name
   ```

4. **Check recent CloudFront logs**:
   ```bash
   aws s3 ls s3://your-bucket-name/logs/ --recursive | tail -20
   ```

5. **Verify DNS records**:
   ```bash
   aws route53 list-resource-record-sets --hosted-zone-id YOUR-ZONE-ID
   ```

## ✨ Final Sign-Off

- [ ] Infrastructure deployed successfully
- [ ] Application accessible at https://app-dev.zamait.in
- [ ] Team trained on deployment process
- [ ] Documentation completed
- [ ] Monitoring configured
- [ ] Rollback procedure tested
- [ ] Ready for production traffic

---

**Deployment Date**: _________________
**Deployed By**: _________________
**Approved By**: _________________
**Notes**: _________________

---

All checks passed? You're ready to go! 🚀

For help, refer to:
- QUICKSTART.md - Quick reference guide
- ARCHITECTURE.md - Detailed architecture
- terraform/README.md - Terraform documentation
- SETUP_COMPLETE.md - Setup summary
