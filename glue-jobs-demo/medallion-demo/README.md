# Medallion Architecture Demo — AWS Glue + S3

A working example of the **Bronze → Silver → Gold** medallion pattern using AWS Glue PySpark jobs, orchestrated by a Glue Workflow. Infrastructure can be provisioned with either **Terraform** or **CloudFormation**.

```
Raw JSON (Bronze)  →  Cleansed Parquet (Silver)  →  Analytical tables (Gold)
```

---

## Architecture overview

```
S3 bucket
├── scripts/                   ← Glue job scripts (uploaded at deploy time)
├── bronze/orders/             ← 1,050 raw JSON records (incl. 50 duplicates)
├── silver/orders/             ← Deduplicated, typed Parquet, partitioned by category
├── gold/
│   ├── daily_sales/           ← Revenue & order count per day
│   ├── customer_summary/      ← Lifetime value + tier (Platinum/Gold/Silver/Bronze)
│   ├── product_performance/   ← Units sold & revenue per product
│   └── category_metrics/      ← Revenue share % per category
└── spark-logs/                ← Spark UI event logs (auto-expire after 30 days)
```

### Glue Workflow

```
[ON_DEMAND trigger]
       │
       ▼
 bronze-ingestion       G.1X × 3 workers  — connections: 1, 2, 3 (spread across AZs)
       │ SUCCEEDED
       ▼
 silver-transformation  G.1X × 3 workers  — connection: 2
       │ SUCCEEDED
       ▼
 gold-aggregation       G.1X × 3 workers  — connection: 3
```

### Glue Network Connections

**3 network connections** are created, one per private subnet / availability zone.

| Connection | Subnet | Purpose |
|---|---|---|
| `medallion-demo-network-connection-1` | private-1 (AZ 0) | Bronze job (all 3 used to spread workers) |
| `medallion-demo-network-connection-2` | private-2 (AZ 1) | Bronze job + dedicated Silver connection |
| `medallion-demo-network-connection-3` | private-3 (AZ 2) | Bronze job + dedicated Gold connection |

All three connections share a single security group that allows unrestricted self-referencing ingress — this is required so Glue workers in the same group can communicate during a Spark shuffle.

### Networking

```
VPC (10.0.0.0/16)
├── Public subnets  (10.0.1.0/24, 10.0.2.0/24)   — NAT gateway lives here
├── Private subnets (10.0.10–12.0/24 × 3 AZs)    — Glue workers run here
├── Internet Gateway → public route table
├── NAT Gateway     → private route table (egress for Glue workers)
└── S3 Gateway VPC Endpoint                        — S3 traffic bypasses NAT (no cost)
```

### Intentional data quality issues in Bronze (fixed by Silver)

| Issue | Rate | Fix applied |
|---|---|---|
| Duplicate records | ~5% | Deduplicate on `order_id` (keep earliest `ingested_at`) |
| Mixed date formats (`MM/DD/YYYY` vs ISO) | ~5% | Normalise to `YYYY-MM-DD` |
| Inconsistent category casing (`electronics` vs `Electronics`) | ~10% | `initcap()` |
| Null `customer_name` | ~5% | Replace with `"Unknown"`, set `dq_flags` |
| Malformed email (missing `@`) | ~3% | Validate with regex, set `dq_flags` |
| Rounding noise on `total_amount` | all rows | Recalculate as `quantity × unit_price` |

---

## Project structure

```
medallion-demo/
├── glue_scripts/
│   ├── bronze_ingestion.py       # Generates 1k records → S3 bronze/ (JSON)
│   ├── silver_transformation.py  # Cleans, deduplicates → S3 silver/ (Parquet)
│   └── gold_aggregation.py       # 4 aggregation tables → S3 gold/ (Parquet)
│
├── terraform/                    # Option A — Terraform
│   ├── main.tf                   # Provider config and locals
│   ├── variables.tf              # All input variables with validation
│   ├── outputs.tf                # Bucket name, job names, CLI run command
│   ├── s3.tf                     # Bucket, encryption, lifecycle, script uploads
│   ├── iam.tf                    # Glue IAM role scoped to the medallion bucket
│   ├── glue.tf                   # 3 Glue jobs + workflow + 3 triggers
│   ├── vpc.tf                    # VPC, subnets, NAT, security group, connections
│   ├── .gitignore                # Excludes state files and tfvars
│   └── terraform.tfvars.example  # Template — copy to terraform.tfvars
│
├── cloudformation/               # Option B — CloudFormation
│   ├── template.yaml             # Single-template: all resources in one file
│   ├── parameters.json.example   # Template — copy to parameters.json
│   └── .gitignore                # Excludes parameters.json
│
├── setup.sh        # Automated Terraform deploy (wraps init → plan → apply)
├── cleanup.sh      # Automated Terraform teardown
├── deploy-cfn.sh   # Automated CloudFormation deploy (stack + script upload)
└── cleanup-cfn.sh  # Automated CloudFormation teardown (empties bucket + deletes stack)
```

---

## Prerequisites

| Tool | Minimum version |
|---|---|
| [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) | 2.x |
| AWS credentials configured | `aws configure` or environment variables |
| [Terraform](https://developer.hashicorp.com/terraform/install) *(Option A only)* | 1.5 |

The IAM principal needs permissions to create: VPCs, S3 buckets, IAM roles/policies, Glue jobs/workflows/triggers/connections, and S3 objects.

---

## Deploy — Option A: Terraform

### 1. Configure variables

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
aws_region    = "us-east-1"
project_name  = "medallion-demo"
bucket_suffix = "123456789012"   # your AWS account ID — makes the bucket name unique
environment   = "dev"
```

### 2. Initialise and apply

```bash
# Automated (recommended)
./setup.sh

# Or manually
terraform init
terraform plan
terraform apply
```

Terraform creates the VPC, S3 bucket, IAM role, 3 Glue network connections, 3 Glue jobs, and the workflow. It also uploads all three PySpark scripts to S3.

### 3. Run the pipeline

```bash
aws glue start-workflow-run \
  --name medallion-demo-workflow \
  --region us-east-1
```

The `run_workflow_command` Terraform output contains this exact command with your resolved values.

### 4. Tear down

```bash
./cleanup.sh
```

Or manually:

```bash
# Empty the versioned bucket first (Terraform cannot delete a non-empty bucket)
aws s3 rm s3://$(terraform output -raw s3_bucket_name) --recursive
terraform destroy
```

---

## Deploy — Option B: CloudFormation

### 1. Configure parameters

```bash
cd cloudformation
cp parameters.json.example parameters.json
```

Edit `parameters.json` and set `BucketSuffix` to your AWS account ID (or any globally unique string).

### 2. Deploy

```bash
# Automated (recommended) — deploys stack and uploads Glue scripts
./deploy-cfn.sh

# Pass the bucket suffix directly to skip the prompt
./deploy-cfn.sh 123456789012
```

The script runs `aws cloudformation deploy`, waits for the stack to reach `CREATE_COMPLETE`, then uploads the three PySpark scripts to the newly created S3 bucket.

> **Note:** Script uploads are a separate step here because CloudFormation has no native equivalent of Terraform's `aws_s3_object` resource. The Glue jobs are created first (they only store the S3 path, not the script itself) and the scripts are uploaded immediately after.

### 3. Deploying manually (without the script)

```bash
aws cloudformation deploy \
  --stack-name medallion-demo \
  --template-file cloudformation/template.yaml \
  --parameter-overrides BucketSuffix=123456789012 Environment=dev \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1

# Then upload scripts
BUCKET=$(aws cloudformation describe-stacks \
  --stack-name medallion-demo \
  --query 'Stacks[0].Outputs[?OutputKey==`S3BucketName`].OutputValue' \
  --output text)

aws s3 cp glue_scripts/ s3://$BUCKET/scripts/ --recursive
```

### 4. Run the pipeline

```bash
aws glue start-workflow-run \
  --name medallion-demo-workflow \
  --region us-east-1
```

The `RunWorkflowCommand` stack output contains this exact command.

### 5. Tear down

```bash
./cleanup-cfn.sh
```

The script empties all object versions from the S3 bucket (required for versioned buckets) before deleting the stack.

---

## Monitor the pipeline

```bash
# Get the latest workflow run ID
aws glue get-workflow-runs \
  --name medallion-demo-workflow \
  --query 'Runs[0].WorkflowRunId' \
  --output text

# Check run status
aws glue get-workflow-run \
  --name medallion-demo-workflow \
  --run-id <run-id>
```

Or open the AWS Glue console → **Workflows** → click the workflow → **Run details**.

---

## Verify output in S3

```bash
# Terraform
BUCKET=$(terraform output -raw s3_bucket_name)

# CloudFormation
BUCKET=$(aws cloudformation describe-stacks \
  --stack-name medallion-demo \
  --query 'Stacks[0].Outputs[?OutputKey==`S3BucketName`].OutputValue' \
  --output text)

# List all layers
aws s3 ls s3://$BUCKET/ --recursive | grep -v spark-logs

# Download a gold table locally
aws s3 cp s3://$BUCKET/gold/category_metrics/ ./category_metrics/ --recursive
```

---

## Querying with Amazon Athena (optional)

Run Glue Crawlers on each layer prefix to populate the Data Catalog, then query with Athena:

```sql
-- Daily revenue trend
SELECT order_date, total_revenue, order_count
FROM gold_daily_sales
ORDER BY order_date;

-- Top customers by lifetime value
SELECT customer_name, lifetime_value, customer_tier
FROM gold_customer_summary
ORDER BY lifetime_value DESC
LIMIT 10;
```

---

## Resources created

| Resource | Count | Notes |
|---|---|---|
| VPC | 1 | `10.0.0.0/16` |
| Public subnets | 2 | For NAT gateway |
| Private subnets | 3 | One per AZ — Glue workers run here |
| Internet Gateway | 1 | |
| NAT Gateway | 1 | Single NAT (dev cost optimisation) |
| S3 VPC Endpoint | 1 | Gateway type — S3 traffic bypasses NAT |
| Security Group | 1 | Self-referencing ingress for Glue workers |
| S3 Bucket | 1 | Versioning + AES-256 + lifecycle rules |
| IAM Role | 1 | `AWSGlueServiceRole` + scoped S3 policy |
| Glue Network Connections | **3** | One per private subnet / AZ |
| Glue Jobs | 3 | Bronze, Silver, Gold |
| Glue Workflow | 1 | |
| Glue Triggers | 3 | 1× ON_DEMAND + 2× CONDITIONAL |

---

## Cost estimate (us-east-1)

| Resource | Approx cost per full pipeline run |
|---|---|
| 3 Glue jobs × 3 DPU × ~3 min each | ~$0.07 |
| S3 storage (< 10 MB total) | < $0.01/month |
| NAT Gateway (idle) | ~$0.045/hour while stack exists |
| **Total per run** | **~$0.08** |

> Tear down the stack when not in use — the NAT Gateway incurs an hourly charge even with no traffic.
