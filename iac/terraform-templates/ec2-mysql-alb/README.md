# EC2 + MySQL RDS + ALB

Three-tier architecture: EC2 instance behind an Application Load Balancer connected to an RDS MySQL database. Default VPC and subnets are auto-detected.

Equivalent to CloudFormation template: `ec2-mysql-alb.yaml`

## Architecture

```
Internet → ALB (port 80) → EC2 (port 80) → RDS MySQL (port 3306)
```

- ALB security group: allows 80 from anywhere
- EC2 security group: allows 80 from ALB only, 22 from anywhere (SSH)
- RDS security group: allows 3306 from EC2 only (not publicly accessible)

## What It Creates

- EC2 instance (AL2023, Apache HTTPD, SSH via key pair)
- RDS MySQL 8.4.8 (private, single-AZ, gp3 storage)
- Application Load Balancer with HTTP listener
- Secrets Manager secret with the auto-generated RDS password
- Security groups with proper isolation between tiers

## Prerequisites

- Terraform >= 1.0
- AWS CLI configured (`aws configure`)
- An EC2 key pair already created in your account and region
- Default VPC with subnets in at least 2 AZs

## Usage

```bash
terraform init
terraform apply -var="key_pair_name=my-key"
```

Or set the key pair in `terraform.tfvars`:

```hcl
key_pair_name = "my-key"
```

## Variables

| Name | Default | Description |
|------|---------|-------------|
| `aws_region` | `us-east-1` | Deploy region (us-east-1 or us-west-2) |
| `name_prefix` | `ec2-mysql-alb` | Prefix for resource names |
| `key_pair_name` | *(required)* | EC2 Key Pair name for SSH access |
| `ec2_instance_type` | `t3.medium` | Allowed: t2/t3/t3a micro\|small\|medium |
| `db_instance_class` | `db.t3.medium` | Allowed: db.t3/t4g micro\|small\|medium |
| `db_name` | `practicedb` | Initial MySQL database name |
| `db_username` | `admin` | RDS master username |

## Outputs

| Name | Description |
|------|-------------|
| `default_vpc_id` | Auto-detected default VPC ID |
| `alb_dns_name` | ALB URL — open in browser |
| `ec2_instance_id` | EC2 Instance ID |
| `ec2_public_ip` | EC2 public IP for SSH |
| `rds_endpoint` | RDS MySQL endpoint (accessible from EC2) |
| `rds_port` | RDS MySQL port |
| `ssh_command` | SSH command with the EC2 public IP |
| `mysql_connect_command` | MySQL connect command (run from EC2) |
| `rds_master_secret_arn` | Secrets Manager secret ARN |
| `rds_master_secret_name` | Secrets Manager secret name |

## Connecting

**SSH to EC2:**
```bash
eval $(terraform output -raw ssh_command | sed 's/<your-key>.pem/my-key.pem/')
# or:
ssh -i my-key.pem ec2-user@$(terraform output -raw ec2_public_ip)
```

**MySQL from EC2 (after SSH):**
```bash
# Retrieve password first:
PASSWORD=$(aws secretsmanager get-secret-value \
  --secret-id $(terraform output -raw rds_master_secret_name) \
  --query SecretString --output text | jq -r '.password')

mysql -h $(terraform output -raw rds_endpoint) \
      -u admin \
      -p"$PASSWORD" \
      practicedb
```

**HTTP via ALB:**
```bash
curl $(terraform output -raw alb_dns_name)
```

## Cleanup

```bash
terraform destroy
```
