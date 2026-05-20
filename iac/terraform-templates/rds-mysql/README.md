# RDS MySQL

Standalone RDS MySQL instance with auto-generated password stored in Secrets Manager.

Equivalent to CloudFormation template: `rds-mysql.yaml`

## What It Creates

- RDS MySQL instance (publicly accessible, gp3 storage, single-AZ)
- Secrets Manager secret with the auto-generated master password
- Security group allowing MySQL port 3306 from anywhere
- DB subnet group

## Prerequisites

- Terraform >= 1.0
- AWS CLI configured (`aws configure`)
- Default VPC with at least 2 subnets in different AZs (or provide your own via variables)

## Usage

```bash
terraform init
terraform apply
```

### Override VPC/subnets

By default the module uses the default VPC. To use a specific VPC:

```hcl
# terraform.tfvars
vpc_id     = "vpc-0123456789abcdef0"
subnet_ids = ["subnet-aaa", "subnet-bbb"]
```

## Variables

| Name | Default | Description |
|------|---------|-------------|
| `aws_region` | `us-east-1` | Deploy region (us-east-1 or us-west-2) |
| `name_prefix` | `rds-mysql` | Prefix for resource names |
| `vpc_id` | `""` | VPC ID (empty = use default VPC) |
| `subnet_ids` | `[]` | Subnet IDs (empty = use default VPC subnets) |
| `db_instance_class` | `db.t3.micro` | Allowed: db.t3/t4g micro\|small\|medium |
| `mysql_version` | `8.4.8` | MySQL version (8.4.8 only) |
| `db_name` | `practicedb` | Initial database name |
| `db_username` | `admin` | Master username |
| `allocated_storage` | `20` | Storage in GB (20–50) |

## Outputs

| Name | Description |
|------|-------------|
| `rds_endpoint` | MySQL hostname |
| `rds_port` | MySQL port |
| `mysql_connect_command` | `mysql` CLI command |
| `rds_master_secret_arn` | Secrets Manager secret ARN |
| `rds_master_secret_name` | Secrets Manager secret name |
| `jdbc_connection_string` | JDBC URL for Java/Spring Boot |

## Retrieve Password

```bash
SECRET=$(terraform output -raw rds_master_secret_name)
aws secretsmanager get-secret-value \
  --secret-id "$SECRET" \
  --query SecretString \
  --output text | jq -r '.password'
```

## Connect

```bash
mysql -h $(terraform output -raw rds_endpoint) \
      -u admin \
      -p practicedb
# Enter password when prompted
```

## Cleanup

```bash
terraform destroy
```
