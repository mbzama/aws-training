# Infrastructure — SQS + DLQ Provisioning

Two IaC options that create identical resources:

| Resource | Name pattern |
|---|---|
| Main SQS queue | `orders-queue-{env}` |
| Dead Letter Queue | `orders-dlq-{env}` |
| CW Alarm (DLQ hit) | `orders-dlq-messages-visible-{env}` |
| CW Alarm (queue depth) | `orders-queue-depth-{env}` |

---

## Queue Configuration

| Setting | Value | Why |
|---|---|---|
| `maxReceiveCount` | 3 | Move to DLQ after 3 failed receive attempts |
| `VisibilityTimeout` | 30 s | Worker has 30 s to process; if not deleted, message reappears |
| `ReceiveMessageWaitTimeSeconds` | 20 s | Long polling — reduces empty API calls |
| Main queue retention | 1 day | Messages should process quickly |
| DLQ retention | 14 days | Engineers need time to inspect and replay failures |

---

## Option A — CloudFormation

```
infra/cloudformation/
  sqs-queues.yml   # Template
  deploy.sh        # Deploy helper script
```

### Deploy

```bash
cd infra/cloudformation

# dev (default)
./deploy.sh

# staging
./deploy.sh staging my-aws-profile

# prod
./deploy.sh prod prod-admin
```

### Manual deploy (no script)

```bash
# Create / update
aws cloudformation deploy \
  --stack-name sqs-dlq-failure-dev \
  --template-file sqs-queues.yml \
  --parameter-overrides Environment=dev \
  --region us-east-1

# View outputs
aws cloudformation describe-stacks \
  --stack-name sqs-dlq-failure-dev \
  --query 'Stacks[0].Outputs'

# Delete
aws cloudformation delete-stack \
  --stack-name sqs-dlq-failure-dev
```

### Parameters

| Parameter | Default | Description |
|---|---|---|
| `Environment` | `dev` | Appended to resource names (`dev` / `staging` / `prod`) |
| `MaxReceiveCount` | `3` | Receive attempts before DLQ redrive |
| `VisibilityTimeoutSeconds` | `30` | Seconds message is hidden after receive |
| `MainQueueRetentionDays` | `1` | Retention for main queue (1 / 4 / 7 / 14) |
| `DLQRetentionDays` | `14` | Retention for DLQ (1 / 4 / 7 / 14) |

---

## Option B — Terraform

```
infra/terraform/
  providers.tf              # AWS provider + Terraform version constraints
  main.tf                   # SQS queues, redrive allow policy, CloudWatch alarms
  variables.tf              # All input variables with descriptions and validation
  outputs.tf                # Queue URLs, ARNs, env snippet
  terraform.tfvars.example  # Copy → terraform.tfvars and fill in
```

### Deploy

```bash
cd infra/terraform

# 1. Copy and edit variables
cp terraform.tfvars.example terraform.tfvars

# 2. Init (downloads AWS provider)
terraform init

# 3. Preview changes
terraform plan

# 4. Apply
terraform apply

# 5. See outputs (for .env.local)
terraform output env_local_snippet
```

### Destroy

```bash
terraform destroy
```

### Variables

| Variable | Default | Description |
|---|---|---|
| `environment` | `dev` | Appended to resource names |
| `aws_region` | `us-east-1` | AWS region |
| `max_receive_count` | `3` | Receive attempts before DLQ redrive |
| `visibility_timeout_seconds` | `30` | Visibility timeout in seconds |
| `main_queue_retention_seconds` | `86400` | Main queue retention (1 day) |
| `dlq_retention_seconds` | `1209600` | DLQ retention (14 days) |
| `alarm_sns_topic_arn` | `""` | SNS topic for alarm notifications (optional) |
| `queue_depth_alarm_threshold` | `100` | Main queue depth that triggers alarm |
| `common_tags` | `{}` | Extra tags merged onto all resources |

---

## After Deploying — Update .env.local

Copy the queue URLs from the IaC output into `apps/sqs-dlq-failure/.env.local`:

```bash
# CloudFormation — URLs are in the stack outputs table
# Terraform — run: terraform output env_local_snippet

# .env.local
AWS_REGION=us-east-1
SQS_QUEUE_URL=https://sqs.us-east-1.amazonaws.com/<account-id>/orders-queue-dev
SQS_DLQ_URL=https://sqs.us-east-1.amazonaws.com/<account-id>/orders-dlq-dev
```

---

## LocalStack vs Real AWS

Both templates default to real AWS.

To test locally with **LocalStack** instead:

```bash
# Start LocalStack
cd apps/sqs-dlq-failure
docker compose up -d

# Use the existing setup script (no IaC needed for local dev)
npm run setup:queues
```

The `.env.local` already points to `http://localhost:4566` for LocalStack.
Use the CloudFormation / Terraform templates when deploying to a real AWS account.
