# Medallion Architecture Demo — AWS Glue + S3

A working example of the **Bronze → Silver → Gold** medallion pattern using AWS Glue PySpark jobs, orchestrated by a Glue Workflow and provisioned with Terraform.

```
Raw JSON (Bronze)  →  Cleansed Parquet (Silver)  →  Analytical tables (Gold)
```

---

## Architecture overview

```
S3 bucket
├── scripts/                   ← Glue job scripts (uploaded by Terraform)
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
 bronze-ingestion       G.1X × 3 workers (3 DPU max)
       │ SUCCEEDED
       ▼
 silver-transformation  G.1X × 3 workers (3 DPU max)
       │ SUCCEEDED
       ▼
 gold-aggregation       G.1X × 3 workers (3 DPU max)
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
│   ├── bronze_ingestion.py      # Generates 1k records → S3 bronze/ (JSON)
│   ├── silver_transformation.py  # Cleans, deduplicates → S3 silver/ (Parquet)
│   └── gold_aggregation.py      # 4 aggregation tables → S3 gold/ (Parquet)
└── terraform/
    ├── main.tf                  # Provider config and locals
    ├── variables.tf             # All input variables with validation
    ├── outputs.tf               # Bucket name, job names, CLI run command
    ├── s3.tf                    # Bucket, encryption, lifecycle, script uploads
    ├── iam.tf                   # Glue IAM role scoped to the medallion bucket
    ├── glue.tf                  # 3 Glue jobs + workflow + 3 triggers
    ├── .gitignore               # Excludes state files and tfvars
    └── terraform.tfvars.example # Template — copy to terraform.tfvars
```

---

## Prerequisites

| Tool | Minimum version |
|---|---|
| [Terraform](https://developer.hashicorp.com/terraform/install) | 1.5 |
| [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) | 2.x |
| AWS credentials configured | `aws configure` or environment variables |

The IAM principal running Terraform needs permissions to create: S3 buckets, IAM roles/policies, Glue jobs/workflows/triggers, and S3 objects.

---

## Deploy

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
terraform init
terraform plan   # review what will be created
terraform apply
```

Terraform creates the S3 bucket, uploads all three scripts, creates the IAM role, and sets up the Glue workflow. The `run_workflow_command` output gives you the exact CLI command to start the pipeline.

### 3. Run the pipeline

```bash
# Copy the command from Terraform output, or run:
aws glue start-workflow-run \
  --name medallion-demo-workflow \
  --region us-east-1
```

The three jobs run sequentially (Bronze → Silver → Gold). Total runtime is roughly 5–8 minutes.

### 4. Monitor progress

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

### 5. Verify output in S3

```bash
BUCKET=$(terraform output -raw s3_bucket_name)

# List all layers
aws s3 ls s3://$BUCKET/ --recursive | grep -v spark-logs

# Preview a gold table (requires AWS CLI S3 Select or download)
aws s3 cp s3://$BUCKET/gold/category_metrics/ ./category_metrics/ --recursive
```

---

## Querying with Amazon Athena (optional)

Run Glue Crawlers on each layer prefix to populate the Data Catalog, then query with Athena:

```sql
-- Example: daily revenue trend
SELECT order_date, total_revenue, order_count
FROM gold_daily_sales
ORDER BY order_date;

-- Example: top customers by lifetime value
SELECT customer_name, lifetime_value, customer_tier
FROM gold_customer_summary
ORDER BY lifetime_value DESC
LIMIT 10;
```

---

## Tear down

```bash
# Empty the bucket first (Terraform cannot delete a non-empty bucket)
aws s3 rm s3://$(terraform output -raw s3_bucket_name) --recursive

terraform destroy
```

---

## Cost estimate (us-east-1)

| Resource | Approx cost per full pipeline run |
|---|---|
| 3 Glue jobs × 3 DPU × ~3 min each | ~$0.07 |
| S3 storage (< 10 MB total) | < $0.01/month |
| **Total per run** | **~$0.08** |

Costs are negligible for development use.
