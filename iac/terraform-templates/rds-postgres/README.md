# RDS PostgreSQL

Standalone RDS PostgreSQL instance with auto-generated password stored in Secrets Manager. Default VPC and subnets are auto-detected.

Equivalent to CloudFormation template: `rds-postgres.yaml`

## What It Creates

- RDS PostgreSQL instance (publicly accessible, gp3 storage, single-AZ)
- Secrets Manager secret with the auto-generated master password
- Security group allowing PostgreSQL port 5432 from anywhere
- DB subnet group (subnets in us-east-1a and us-east-1b)

## Prerequisites

- Terraform >= 1.0
- AWS CLI configured (`aws configure`)
- Default VPC with subnets in `us-east-1a` and `us-east-1b`

## Usage

```bash
terraform init
terraform apply
```

## Variables

| Name | Default | Description |
|------|---------|-------------|
| `aws_region` | `us-east-1` | Deploy region (us-east-1 required) |
| `name_prefix` | `rds-postgres` | Prefix for resource names |
| `db_instance_class` | `db.t3.micro` | Allowed: db.t3/t4g micro\|small\|medium |
| `postgres_version` | `16.3` | PostgreSQL version: 16.3, 15.7, 14.12, or 13.15 |
| `db_name` | `practicedb` | Initial database name |
| `db_username` | `pgadmin` | Master username (cannot be "postgres") |
| `allocated_storage` | `20` | Storage in GB (20–50) |

## Outputs

| Name | Description |
|------|-------------|
| `default_vpc_id` | Auto-detected default VPC ID |
| `rds_endpoint` | PostgreSQL hostname |
| `rds_port` | PostgreSQL port |
| `rds_master_secret_arn` | Secrets Manager secret ARN |
| `rds_master_secret_name` | Secrets Manager secret name |
| `psql_connect_command` | `psql` CLI command |
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
PGPASSWORD=<password> psql \
  -h $(terraform output -raw rds_endpoint) \
  -U pgadmin \
  -d practicedb
```

Or use pgAdmin, DBeaver, or any other PostgreSQL client with the endpoint from `terraform output`.

## Cleanup

```bash
terraform destroy
```
