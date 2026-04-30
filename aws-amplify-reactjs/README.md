# AWS Amplify React App

A production-ready React application hosted on **AWS Amplify** with a custom domain (`myapp.example.com`), HTTPS via ACM, and infrastructure managed with Terraform.

---

## Project Structure

```
aws-amplify-reactjs/
├── public/
│   ├── index.html          # CRA HTML template
│   └── manifest.json       # PWA manifest
├── src/
│   ├── App.js              # Landing page component
│   ├── App.css             # Component styles
│   ├── index.js            # React entry point
│   ├── index.css           # Global base styles
│   └── reportWebVitals.js  # Performance instrumentation
├── infrastructure/
│   ├── provider.tf         # AWS provider (us-east-1)
│   ├── variables.tf        # Input variable declarations
│   ├── acm-certificate.tf  # ACM cert + DNS validation wait
│   ├── amplify.tf          # Amplify app, branch & custom domain
│   ├── outputs.tf          # Useful output values
│   └── terraform.tfvars.example  # Template — copy & fill in
├── amplify.yml             # Amplify build specification
├── package.json
└── .gitignore
```

---

## Prerequisites

| Tool | Minimum version | Purpose |
|------|----------------|---------|
| Node.js | 18.x | Run and build the React app |
| npm | 9.x | Package management |
| Terraform | 1.5.x | Provision AWS infrastructure |
| AWS CLI | 2.x | Authenticate Terraform to AWS |
| GitHub account | — | Source repository for Amplify CI/CD |
| GoDaddy account | — | DNS management for example.com |

---

## Part 1 — Deploy via the Amplify Console (no Terraform needed)

This is the quickest path if you just want the app running.

### Step 1 — Push the code to GitHub

```bash
# In the project root
git init
git add .
git commit -m "Initial commit"
git remote add origin https://github.com/YOUR_ORG/YOUR_REPO.git
git push -u origin main
```

### Step 2 — Create a new Amplify app in the AWS Console

1. Open the [AWS Amplify Console](https://us-east-1.console.aws.amazon.com/amplify/home).
2. Click **"New app"** → **"Host web app"**.
3. Choose **GitHub** as the source provider and click **Continue**.
4. Authorize Amplify to access your GitHub account when prompted.
5. Select your repository and the **main** branch.
6. On the **Configure build settings** screen, Amplify will auto-detect the `amplify.yml` in the repository root — leave it as-is.
7. Click **"Save and deploy"**.

Amplify will clone the repo, run `npm ci` and `npm run build`, and publish the `build/` directory to its CDN. The deployment takes approximately 2–3 minutes.

Once complete, Amplify gives you a temporary URL like:
```
https://main.d1abc2def3ghi.amplifyapp.com
```

---

## Part 2 — Provision Infrastructure with Terraform

Use Terraform when you need repeatable, version-controlled infrastructure. The Terraform code provisions the ACM certificate and wires up the Amplify custom domain.

### Step 1 — Configure AWS credentials

```bash
aws configure
# Enter your Access Key ID, Secret Access Key, region (us-east-1), and output format (json)
```

### Step 2 — Create a GitHub personal access token

1. Go to **GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)**.
2. Click **Generate new token (classic)**.
3. Set a note (e.g. "Amplify Terraform") and expiry.
4. Select the **repo** scope (full control of private repositories).
5. Click **Generate token** and copy the token — you will not see it again.

### Step 3 — Set Terraform variable values

```bash
cd infrastructure
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
app_name           = "aws-amplify-reactjs"
github_repository  = "https://github.com/YOUR_ORG/YOUR_REPO"
github_oauth_token = "ghp_XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
app_domain_name    = "myapp.example.com"
```

> **Security**: `terraform.tfvars` is listed in `.gitignore` and must never be committed to source control.

### Step 4 — Initialise and apply Terraform

```bash
terraform init
terraform plan    # Review what will be created
terraform apply   # Type "yes" to confirm
```

After `terraform apply` completes, the terminal will print output values including the ACM CNAME records needed for DNS validation.

---

## Part 3 — DNS Validation: Getting the CNAME Records from ACM

ACM needs proof that you own `myapp.example.com` before it will issue the certificate. It does this by asking you to add a specific CNAME record to your DNS.

### Via Terraform outputs (if you used Terraform)

After `terraform apply`, run:

```bash
terraform output acm_validation_cname_name
terraform output acm_validation_cname_value
```

Example values (yours will be different):

```
acm_validation_cname_name  = "_abc123def456.myapp.example.com."
acm_validation_cname_value = "_xyz789uvw012.acm-validations.aws."
```

### Via the AWS Console (if you skipped Terraform)

1. Open [AWS Certificate Manager](https://us-east-1.console.aws.amazon.com/acm/home?region=us-east-1).
2. Click the certificate for `myapp.example.com`.
3. Under **Domains**, find the row for `myapp.example.com`.
4. Copy the **CNAME name** and **CNAME value** shown there.

---

## Part 4 — Adding CNAME Records in GoDaddy

### Step 1 — Log in to GoDaddy

1. Go to [godaddy.com](https://www.godaddy.com) and sign in.
2. Click your account menu (top right) → **My Products**.
3. Find your `example.com` domain and click **DNS** (or **Manage DNS**).

### Step 2 — Add the ACM validation CNAME

You need to add **two** separate CNAME records: one for ACM certificate validation and one for Amplify's domain verification.

#### Record 1 — ACM certificate validation

| Field | What to enter |
|-------|--------------|
| **Type** | `CNAME` |
| **Name / Host** | The portion of `acm_validation_cname_name` **before** `.example.com.` — GoDaddy appends the root domain automatically. For example if the full name is `_abc123def456.myapp.example.com.` enter `_abc123def456.app-dev` |
| **Value / Points to** | The full `acm_validation_cname_value` without the trailing dot. Example: `_xyz789uvw012.acm-validations.aws` |
| **TTL** | `1 hour` (or `3600`) |

Click **Save**.

#### Record 2 — Amplify domain verification

After running `terraform apply` (or configuring the custom domain in the Amplify Console), Amplify will display its own CNAME record in the **Domain management** panel of the Amplify Console. Add that record following the same steps above.

> You can find it at: **Amplify Console → your app → Domain management → myapp.example.com**

### Step 3 — Wait for propagation

- ACM validation typically completes within **5–30 minutes** after the DNS record is live.
- Global DNS propagation can take up to **48 hours**, but is usually much faster.
- You can monitor the certificate status in the ACM console — wait for the status to change from **"Pending validation"** to **"Issued"**.

### Step 4 — Verify the deployment

Once the certificate is issued and DNS has propagated:

```bash
# Should return HTTP 200 and your React app HTML
curl -I https://myapp.example.com

# Or simply open in a browser
open https://myapp.example.com
```

---

## Local Development

```bash
# Install dependencies
npm install

# Start the development server (http://localhost:3000)
npm start

# Run tests
npm test

# Create a production build locally
npm run build
```

---

## Terraform Reference

| Command | Description |
|---------|-------------|
| `terraform init` | Download providers and initialise the working directory |
| `terraform plan` | Preview changes without applying them |
| `terraform apply` | Apply changes (prompts for confirmation) |
| `terraform output` | Display all output values |
| `terraform destroy` | Tear down all managed resources |

---

## Troubleshooting

**Certificate stuck in "Pending validation"**
- Verify the CNAME record is correct in GoDaddy (no extra spaces, correct host value).
- Use `dig` or [dnschecker.org](https://dnschecker.org) to confirm the record has propagated.
- Ensure you stripped the trailing dot from both the name and value when entering in GoDaddy.

**Amplify build fails**
- Check the build log in the Amplify Console for the exact error.
- Confirm `amplify.yml` is in the repository root.
- Ensure the `package.json` `build` script is `react-scripts build`.

**Custom domain shows "Domain activation in progress"**
- This is normal immediately after adding the Amplify CNAME in GoDaddy.
- Wait 5–15 minutes and refresh the Domain management panel.

**`terraform apply` fails with "certificate not yet issued"**
- The `aws_acm_certificate_validation` resource has a 45-minute timeout.
- Add the ACM CNAME to GoDaddy first, then re-run `terraform apply`.
