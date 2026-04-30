# Troubleshooting Guide

## Common Issues and Solutions

### 🔴 Infrastructure Deployment Issues

#### Issue: "Error: missing required provider configuration"

**Error message:**
```
Error: missing required provider configuration
```

**Solution:**
1. Ensure AWS credentials are configured:
   ```bash
   aws configure
   ```
2. Test credentials:
   ```bash
   aws sts get-caller-identity
   ```
3. Reinitialize Terraform:
   ```bash
   cd terraform
   rm -rf .terraform/
   terraform init
   ```

---

#### Issue: "Error: resource quota exceeded"

**Error message:**
```
Error: creating CloudFront Distribution: AccessDenied: User is not authorized
```

**Cause:** Insufficient IAM permissions

**Solution:**
1. Verify IAM user has these permissions:
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Action": [
           "s3:*",
           "cloudfront:*",
           "route53:*",
           "acm:*"
         ],
         "Resource": "*"
       }
     ]
   }
   ```
2. Attach permissions to your IAM user
3. Wait 15 minutes for permissions to propagate
4. Try again

---

#### Issue: "Error: certificate not found"

**Error message:**
```
Error retrieving certificate for domain *.zamait.in
```

**Cause:** ACM certificate doesn't exist or is in wrong region

**Solution:**
1. Verify certificate exists in us-east-1:
   ```bash
   aws acm list-certificates --region us-east-1
   ```
2. Certificate must have status "ISSUED"
3. If certificate is in a different region, move it (manual process in AWS Console)
4. If certificate doesn't exist:
   - Go to AWS Console → ACM
   - Create new certificate for `*.zamait.in`
   - Verify domain ownership
   - Wait for "ISSUED" status

---

#### Issue: "Error: resource already exists"

**Error message:**
```
Error: resource already exists: s3 bucket already exists
```

**Cause:** S3 bucket name is globally unique and already taken

**Solution:**
1. Change the project name in terraform.tfvars:
   ```hcl
   project_name = "app2"  # Changed from "app"
   ```
2. Run terraform plan again:
   ```bash
   terraform plan
   ```
3. Apply with new name:
   ```bash
   terraform apply
   ```

---

### 🔴 DNS Issues

#### Issue: "DNS not resolving"

**Error message:**
```
$ nslookup app-dev.zamait.in
** server can't find app-dev.zamait.in: NXDOMAIN
```

**Cause:** DNS records not propagated yet or Route53 misconfigured

**Solution:**
1. Verify Route53 records were created:
   ```bash
   aws route53 list-resource-record-sets --hosted-zone-id YOUR-ZONE-ID
   ```
   Should see both A and AAAA records for app-dev.zamait.in

2. Check Route53 nameservers:
   ```bash
   aws route53 get-hosted-zone --id YOUR-ZONE-ID
   # Note the nameservers
   ```

3. Verify nameservers in registrar:
   - Go to your domain registrar (e.g., GoDaddy, Namecheap)
   - Update nameservers to match Route53 ones

4. Wait for DNS propagation:
   ```bash
   # Check propagation status
   for i in {1..10}; do
     echo "Attempt $i:"
     nslookup app-dev.zamait.in
     sleep 10
   done
   ```
   - Can take 5 minutes to 48 hours (usually 15-30 minutes)

5. If still not working, clear your local DNS cache:
   ```bash
   # macOS
   sudo dscacheutil -flushcache
   
   # Linux
   sudo systemctl restart nscd
   
   # Windows (PowerShell as Admin)
   Clear-DnsClientCache
   ```

---

#### Issue: "Certificate domain mismatch"

**Error message:**
```
SSL: CERTIFICATE_VERIFY_FAILED - hostname doesn't match certificate
```

**Cause:** DNS pointing to wrong CloudFront domain or certificate issue

**Solution:**
1. Verify your DNS record:
   ```bash
   dig app-dev.zamait.in +short
   ```
   Should output CloudFront domain like: `d23aef3f.cloudfront.net`

2. Verify Route53 alias is correct:
   ```bash
   aws route53 list-resource-record-sets --hosted-zone-id YOUR-ZONE-ID | grep app-dev
   ```
   Look for alias target pointing to CloudFront domain

3. Verify certificate is attached to CloudFront:
   ```bash
   aws cloudfront get-distribution --id YOUR-DISTRIB-ID | \
     grep -A 10 "ViewerCertificate"
   ```

---

### 🔴 S3 Upload Issues

#### Issue: "Access Denied when uploading to S3"

**Error message:**
```
Error: Access Denied
upload failed: "./out/index.html" to "s3://bucket/index.html"
```

**Cause:** IAM user doesn't have S3 permissions

**Solution:**
1. Verify AWS credentials:
   ```bash
   aws sts get-caller-identity
   ```

2. Test S3 access:
   ```bash
   aws s3 ls
   ```

3. If access denied, ensure IAM user has permissions:
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Action": "s3:*",
         "Resource": "*"
       }
     ]
   }
   ```

4. If using temporary credentials (STS), ensure they haven't expired

---

#### Issue: "Bucket not found"

**Error message:**
```
Error: The specified bucket does not exist
```

**Cause:** S3 bucket wasn't created or wrong bucket name

**Solution:**
1. Check if bucket exists:
   ```bash
   aws s3 ls
   ```

2. Get bucket name from Terraform:
   ```bash
   cd terraform
   terraform output s3_bucket_name
   ```

3. If bucket doesn't exist, run terraform apply:
   ```bash
   make apply
   ```

4. Verify bucket creation:
   ```bash
   aws s3 ls | grep app-dev
   ```

---

#### Issue: "403 Forbidden - Access Denied from CloudFront"

**Error when accessing https://app-dev.zamait.in**:
```
403 Forbidden
The request could not be satisfied.
Error Code: AccessDenied
```

**Cause:** S3 bucket policy doesn't allow CloudFront access

**Solution:**
1. Verify bucket policy:
   ```bash
   aws s3api get-bucket-policy --bucket your-bucket-name
   ```

2. Check if policy includes CloudFront OAC:
   ```bash
   aws s3api get-bucket-policy --bucket your-bucket-name | \
     grep "cloudfront.amazonaws.com"
   ```

3. If missing, reapply Terraform:
   ```bash
   cd terraform
   terraform apply -auto-approve
   ```

4. Verify files are in S3:
   ```bash
   aws s3 ls s3://your-bucket-name/
   ```

5. If CloudFront distribution is new, wait 5-10 minutes

---

### 🔴 CloudFront Issues

#### Issue: "CloudFront returning 404"

**Error message:**
```
404 Not Found
-or-
The request could not be satisfied
Error Code: NoSuchKey
```

**Cause:** Files not uploaded to S3 or wrong S3 path

**Solution:**
1. Verify files exist in S3:
   ```bash
   aws s3 ls s3://app-dev-us-east-1/ --recursive
   ```

2. Check if index.html exists:
   ```bash
   aws s3 ls s3://app-dev-us-east-1/index.html
   ```

3. If missing, upload files:
   ```bash
   make deploy
   # or
   npm run build
   aws s3 sync ./out s3://app-dev-us-east-1/ --delete
   ```

4. Check CloudFront origin:
   ```bash
   aws cloudfront get-distribution --id YOUR-DISTRIB-ID | \
     grep -A 5 "DomainName"
   ```

5. Clear CloudFront cache:
   ```bash
   make invalidate
   ```

---

#### Issue: "CloudFront taking too long to load"

**Symptoms:** Page loads very slowly (> 5 seconds)

**Cause:** 
- New CloudFront distribution (takes ~15-20 minutes to deploy)
- Cache not hit (first request always slower)
- Large bundle size
- No compression enabled

**Solution:**
1. Wait for distribution to fully deploy:
   ```bash
   aws cloudfront get-distribution --id YOUR-DISTRIB-ID | \
     grep "Status"
   ```
   Status should be "Deployed"

2. Check if it's the first request (check response headers):
   ```bash
   curl -I https://app-dev.zamait.in
   ```
   Look for `X-Cache: Miss from cloudfront` (first) or `Hit from cloudfront` (cached)

3. Reduce bundle size:
   ```bash
   npm run build
   du -sh out/
   ```
   Verify reasonable size (< 50MB typical)

4. Verify compression is enabled:
   ```bash
   curl -H "Accept-Encoding: gzip" -I https://app-dev.zamait.in
   ```
   Should see `Content-Encoding: gzip`

---

#### Issue: "CloudFront cache showing old version"

**Symptom:** New deployed version not showing up

**Cause:** Cache not invalidated properly

**Solution:**
1. Manually invalidate CloudFront:
   ```bash
   aws cloudfront create-invalidation \
     --distribution-id YOUR-DISTRIB-ID \
     --paths "/*"
   ```

2. Wait for invalidation to complete:
   ```bash
   aws cloudfront list-invalidations --distribution-id YOUR-DISTRIB-ID
   ```
   Status should be "Completed"

3. Clear browser cache:
   - Chrome: Ctrl+Shift+Delete (Windows) or Cmd+Shift+Delete (Mac)
   - Firefox: Ctrl+H, Clear Recent History
   - Safari: Develop → Empty Caches

4. Disable browser cache (for testing):
   ```bash
   # Using curl (always fresh)
   curl -H "Cache-Control: no-cache" https://app-dev.zamait.in
   ```

---

### 🔴 Build Issues

#### Issue: "Build fails with 'output: export not configured'"

**Error message:**
```
Error: Cannot use the App Router with output: export
```

**Cause:** next.config.ts doesn't have static export enabled

**Solution:**
1. Update next.config.ts:
   ```typescript
   import type { NextConfig } from 'next';

   const nextConfig: NextConfig = {
     output: 'export',              // Add this line
     trailingSlash: true,           // Add this line
     images: {
       unoptimized: true,           // Add this line
     },
   };

   export default nextConfig;
   ```

2. Delete old build:
   ```bash
   rm -rf out/ .next/
   ```

3. Rebuild:
   ```bash
   npm run build
   ```

---

#### Issue: "Build fails with 'image optimization not available'"

**Error message:**
```
Error: Image Optimization is not available with 'output: export'
```

**Cause:** Using next/image without unoptimized flag

**Solution:**
1. Update next.config.ts:
   ```typescript
   const nextConfig: NextConfig = {
     images: {
       unoptimized: true,  // Add this!
     },
   };
   ```

2. Update Image components in code:
   ```typescript
   // Add this to images that need external loading
   import Image from 'next/image';
   
   <Image
     src="/path/to/image.jpg"
     alt="description"
     unoptimized={true}  // Add this if still having issues
   />
   ```

---

#### Issue: "Build fails with 'API routes not available'"

**Error message:**
```
Error: API routes are not compatible with 'output: export'
```

**Cause:** Using Next.js API routes with static export

**Solution:**
1. Remove API routes (they can't be static)
2. Use external API instead:
   ```typescript
   // Instead of /api/endpoint, use:
   const response = await fetch('https://external-api.com/endpoint');
   ```

3. Or switch to a server-based deployment (not S3 static)

---

### 🔴 Deployment Script Issues

#### Issue: "deploy.sh: command not found"

**Error message:**
```
bash: deploy.sh: command not found
```

**Cause:** Script not executable or wrong path

**Solution:**
1. Make script executable:
   ```bash
   chmod +x deploy.sh
   ```

2. Run from correct directory:
   ```bash
   cd /path/to/project
   ./deploy.sh
   ```

3. Or run with bash explicitly:
   ```bash
   bash deploy.sh
   ```

---

#### Issue: "deploy.sh fails with S3 bucket not found"

**Error message:**
```
upload failed: "./out/index.html" to "s3://bucket/"
An error occurred (NoSuchBucket) when calling the PutObject operation:
```

**Cause:** Terraform outputs not available or S3 bucket not created

**Solution:**
1. Ensure Terraform infrastructure exists:
   ```bash
   cd terraform
   terraform state list
   ```

2. Create infrastructure if needed:
   ```bash
   make init
   make apply
   ```

3. Verify outputs:
   ```bash
   terraform output
   ```

---

#### Issue: "Make command not found"

**Error message:**
```
make: command not found
```

**Cause:** Make utility not installed

**Solution:**
1. Install make:
   ```bash
   # macOS (with Homebrew)
   brew install make
   
   # Linux (Ubuntu/Debian)
   sudo apt-get install make
   
   # Windows (use WSL or Git Bash)
   ```

2. Or run commands directly:
   ```bash
   # Instead of: make deploy
   cd terraform && terraform output -raw s3_bucket_name
   npm run build
   aws s3 sync ./out s3://your-bucket/ --delete
   ```

---

### 🔴 Terraform State Issues

#### Issue: "Terraform state locked"

**Error message:**
```
Error: Error acquiring the lock
```

**Cause:** Another terraform operation running or state locked

**Solution:**
1. Check for running terraform processes:
   ```bash
   ps aux | grep terraform
   ```

2. If no processes running, force unlock:
   ```bash
   cd terraform
   terraform force-unlock LOCK_ID
   ```
   (Get LOCK_ID from error message)

3. If using remote state, check other users:
   ```bash
   terraform state list
   ```

---

#### Issue: "Terraform plan shows destroying resources unnecessarily"

**Symptom:** `terraform plan` shows resources will be deleted

**Cause:** Variables changed or state corrupted

**Solution:**
1. Review the plan carefully:
   ```bash
   terraform plan -out=tfplan
   cat tfplan  # Review proposed changes
   ```

2. Don't apply if deleting important resources!

3. Check variables match terraform.tfvars:
   ```bash
   terraform plan -var-file=terraform.tfvars
   ```

4. Import state if needed:
   ```bash
   terraform import aws_s3_bucket.app_bucket your-bucket-name
   ```

---

#### Issue: "Terraform destroy hangs"

**Symptom:** `make destroy` or `terraform destroy` hangs

**Cause:** S3 bucket has objects or distribution still deploying

**Solution:**
1. Cancel command (Ctrl+C)

2. Delete S3 contents first:
   ```bash
   aws s3 rm s3://your-bucket-name/ --recursive
   ```

3. Then destroy:
   ```bash
   make destroy
   ```

4. If still hangs, check what's taking time:
   ```bash
   terraform state list
   ```

---

### 🔴 Performance Issues

#### Issue: "Static assets not caching properly"

**Symptom:** _next/*.js files show Cache: Miss every time

**Cause:** Cache TTL too low or query parameters messing up cache

**Solution:**
1. Check response headers:
   ```bash
   curl -I https://app-dev.zamait.in/_next/static/...js
   ```
   Should show: `Cache-Control: public, max-age=31536000, immutable`

2. Increase cache TTL in terraform:
   ```hcl
   cf_max_ttl = 31536000  # 1 year
   ```

3. Redeploy:
   ```bash
   make apply
   ```

---

#### Issue: "Large bundle size causing slow loads"

**Symptom:** Page takes > 3 seconds to load

**Cause:** Bundle size too large or not compressed

**Solution:**
1. Check build output size:
   ```bash
   du -sh out/
   find out -type f | sort -k5 -rn | head -20
   ```

2. Optimize bundle:
   - Remove unused dependencies
   - Use dynamic imports for code splitting
   - Lazy load heavy components

3. Verify compression:
   ```bash
   curl -H "Accept-Encoding: gzip" -I https://app-dev.zamait.in
   ```

---

### 🔴 GitHub Actions Issues

#### Issue: "GitHub Actions workflow fails with AWS credentials error"

**Error message:**
```
Error: The AWS credentials are not available
```

**Cause:** GitHub Secrets not configured

**Solution:**
1. Go to repository Settings → Secrets
2. Add these secrets:
   - `AWS_ACCESS_KEY_ID`: Your AWS access key
   - `AWS_SECRET_ACCESS_KEY`: Your AWS secret key

3. Ensure variable names match `.github/workflows/deploy.yml`:
   ```yaml
   - uses: aws-actions/configure-aws-credentials@v4
     with:
       aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
       aws-secret_access_key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
   ```

---

#### Issue: "GitHub Actions workflow takes too long"

**Symptom:** Workflow runs for > 20 minutes

**Cause:** 
- First run (installing dependencies)
- Large dependencies
- Waiting for CloudFront invalidation

**Solution:**
1. Use cache for dependencies:
   ```yaml
   - uses: actions/setup-node@v4
     with:
       node-version: '18'
       cache: 'npm'  # Cache npm modules
   ```

2. Parallelize jobs (already done in workflow)

3. Use faster builders
   - Turborepo
   - esbuild instead of webpack etc

---

### 🔴 Cost Issues

#### Issue: "Unexpected AWS bill"

**Cause:**
- Large data transfer from CloudFront
- Too many CloudFront requests
- Long retention of versioned S3 objects

**Solution:**
1. Check CloudFront metrics:
   ```bash
   aws cloudwatch get-metric-statistics \
     --namespace AWS/CloudFront \
     --metric-name BytesDownloaded
   ```

2. Review S3 storage:
   ```bash
   aws s3 ls --summarize --human-readable --recursive s3://your-bucket/
   ```

3. Reduce costs:
   - Enable S3 Intelligent-Tiering
   - Reduce CloudFront price class
   - Implement CloudFront geo-blocking
   - Set S3 lifecycle policies

---

## 🆘 Getting Help

If you can't find a solution:

1. **Check logs**:
   ```bash
   # CloudFront
   aws s3 ls s3://your-bucket/logs/ --recursive
   
   # Terraform
   TF_LOG=DEBUG terraform apply
   ```

2. **AWS Support**:
   - Go to AWS Console → Support
   - Create a support ticket
   - Include error messages and terraform state

3. **GitHub Issues**:
   - Search existing issues
   - Create new issue with:
     - Error message (full)
     - Steps to reproduce
     - Configuration (sanitized)
     - Environment info

4. **Stack Overflow**:
   - Tag: terraform, aws, cloudfront, nextjs
   - Include minimal reproducible example

---

## 📞 Emergency Rollback

If something is critically broken:

```bash
# Get previous version from S3
aws s3 ls s3://your-bucket/ --recursive | head -20

# Restore from version
aws s3api list-object-versions --bucket your-bucket | grep index.html

# Restore specific version
aws s3api get-object \
  --bucket your-bucket \
  --key index.html \
  --version-id VERSION_ID \
  restored-index.html

# Re-upload
aws s3 cp restored-index.html s3://your-bucket/index.html

# Invalidate CloudFront
aws cloudfront create-invalidation --distribution-id YOUR-ID --paths "/*"
```

Good luck! 🍀
