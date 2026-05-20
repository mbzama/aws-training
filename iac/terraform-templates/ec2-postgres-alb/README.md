# EC2 + PostgreSQL RDS + ALB

Three-tier architecture: EC2 instance behind an Application Load Balancer connected to an RDS PostgreSQL database. Connects via **EC2 Instance Connect** — no key pair required.

Equivalent to CloudFormation template: `ec2-postgres-alb.yaml`

## Architecture

```
Internet → ALB (port 80) → EC2 (port 80) → RDS PostgreSQL (port 5432)
```

- ALB security group: allows 80 from anywhere
- EC2 security group: allows 80 from ALB only, 22 from anywhere (EC2 Instance Connect)
- RDS security group: allows 5432 from EC2 only (not publicly accessible)

## What It Creates

- EC2 instance (AL2023, Apache HTTPD + postgresql15 client, EC2 Instance Connect)
- IAM role + instance profile for EC2 Instance Connect
- RDS PostgreSQL 16.3 (private, single-AZ, gp3 storage)
- Application Load Balancer with HTTP listener
- Secrets Manager secret with the auto-generated RDS password
- Security groups with proper isolation between tiers

## Prerequisites

- Terraform >= 1.0
- AWS CLI configured (`aws configure`)
- Default VPC with subnets in at least 2 AZs (us-east-1 required)

## Usage

```bash
terraform init
terraform apply
```

## Variables

| Name | Default | Description |
|------|---------|-------------|
| `aws_region` | `us-east-1` | Deploy region (us-east-1 only) |
| `name_prefix` | `app` | Short prefix for resource names |
| `ec2_instance_type` | `t3.medium` | Allowed: t2/t3/t3a micro\|small\|medium |
| `db_instance_class` | `db.t3.medium` | Allowed: db.t3/t4g micro\|small\|medium |
| `db_name` | `practicedb` | Initial PostgreSQL database name |
| `db_username` | `pgadmin` | RDS master username (cannot be "postgres") |

## Outputs

| Name | Description |
|------|-------------|
| `default_vpc_id` | Auto-detected default VPC ID |
| `alb_dns_name` | ALB URL — open in browser |
| `ec2_instance_id` | EC2 Instance ID |
| `ec2_public_ip` | EC2 public IP |
| `rds_endpoint` | RDS PostgreSQL endpoint (accessible from EC2) |
| `rds_port` | RDS PostgreSQL port |
| `ec2_connect_info` | EC2 Instance Connect instructions |
| `postgresql_connect_command` | psql connect command (run from EC2) |
| `rds_secret_arn` | Secrets Manager secret ARN |
| `rds_secret_name` | Secrets Manager secret name |

## Connecting

**EC2 Instance Connect (no key pair):**
1. Go to EC2 Console → select the instance → click **Connect** → **EC2 Instance Connect**
2. Or use the AWS CLI:
   ```bash
   aws ec2-instance-connect ssh --instance-id $(terraform output -raw ec2_instance_id)
   ```

**PostgreSQL from EC2 (after connecting to EC2):**
```bash
# Retrieve password:
PASSWORD=$(aws secretsmanager get-secret-value \
  --secret-id $(terraform output -raw rds_secret_name) \
  --query SecretString --output text | jq -r '.password')

psql -h $(terraform output -raw rds_endpoint) \
     -U pgadmin \
     -d practicedb
# Enter password when prompted
```

**HTTP via ALB:**
```bash
curl $(terraform output -raw alb_dns_name)
```

## Cleanup

```bash
terraform destroy
```
