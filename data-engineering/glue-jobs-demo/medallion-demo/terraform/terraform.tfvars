# Copy this file to terraform.tfvars and fill in your values.
# terraform.tfvars is gitignored — never commit it with real account IDs.

aws_region   = "us-east-1"
project_name = "medallion-demo"

# Must be globally unique. Using your AWS account ID is a safe default:
#   bucket_suffix = "763517787124"
bucket_suffix = "763517787124"

environment         = "dev"
glue_version        = "4.0"
worker_type         = "G.1X"   # 1 DPU per worker
number_of_workers   = 2        # 2 workers × 1 DPU = 2 DPU per job; sequential jobs → max 2 DPU concurrent
job_timeout_minutes = 60

# Narrowed to /28 (11 usable IPs each) to force worker spread across all 3 subnets.
# Restore to /24 after spread testing is confirmed.
private_subnet_cidrs = ["10.0.10.0/28", "10.0.11.0/28", "10.0.12.0/28"]
