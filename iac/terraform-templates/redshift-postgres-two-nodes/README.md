# Redshift Two-Node + PostgreSQL RDS

Two-node Amazon Redshift cluster (multi-node) alongside a PostgreSQL RDS instance. Redshift can reach PostgreSQL on port 5432 via a scoped security group.

Equivalent to CloudFormation template: `redshift-postgres-two-nodes.yaml`

## What It Creates

- Redshift two-node cluster (ra3.large × 2, multi-node, encrypted, publicly accessible)
- RDS PostgreSQL 17.2 (db.t3.medium, private, accessible from Redshift only)
- Secrets Manager secrets for both Redshift and PostgreSQL credentials
- Redshift subnet group + PostgreSQL DB subnet group
- Security group for Redshift (port 5439 open)
- Security group for PostgreSQL (port 5432 from Redshift only)

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
| `aws_region` | `us-east-1` | Deploy region (us-east-1 or us-west-2) |
| `name_prefix` | `redshift-two-nodes` | Prefix for resource names |
| `node_type` | `ra3.large` | Redshift node type |
| `db_name` | `practicedb` | Redshift database name (lowercase) |
| `db_username` | `rsadmin` | Redshift master username (lowercase, not "admin"/"root"/"postgres") |
| `pg_db_name` | `pgpracticedb` | PostgreSQL database name |
| `pg_username` | `pgadmin` | PostgreSQL master username (not "postgres") |

## Outputs

| Name | Description |
|------|-------------|
| `default_vpc_id` | Auto-detected default VPC ID |
| `cluster_endpoint` | Redshift cluster endpoint |
| `cluster_port` | Redshift port (5439) |
| `cluster_jdbc_url` | JDBC URL for DBeaver / SQL Workbench/J |
| `psql_connect_command` | psql command for Redshift |
| `postgresql_endpoint` | PostgreSQL RDS endpoint |
| `postgresql_port` | PostgreSQL port (5432) |
| `postgresql_connect_command` | psql command for PostgreSQL RDS |
| `redshift_secret_arn` | Secrets Manager ARN for Redshift credentials |
| `postgresql_secret_arn` | Secrets Manager ARN for PostgreSQL credentials |

## Retrieve Passwords

```bash
# Redshift password
aws secretsmanager get-secret-value \
  --secret-id "${var.name_prefix}-redshift-master" \
  --query SecretString --output text | jq -r '.password'

# PostgreSQL password
aws secretsmanager get-secret-value \
  --secret-id "${var.name_prefix}-postgres-master" \
  --query SecretString --output text | jq -r '.password'
```

## Connect to Redshift

Using psql (requires PostgreSQL 8+ client or Redshift ODBC/JDBC driver):

```bash
ENDPOINT=$(terraform output -raw cluster_endpoint)
PORT=$(terraform output -raw cluster_port)
psql -h "$ENDPOINT" -p "$PORT" -U rsadmin -d practicedb
```

Using DBeaver or SQL Workbench/J — use the `cluster_jdbc_url` output as the JDBC URL.

## Single-Node vs Two-Node

| | `redshift-postgres-single-node` | `redshift-postgres-two-nodes` |
|---|---|---|
| `cluster_type` | `single-node` | `multi-node` |
| `number_of_nodes` | 1 | 2 |
| Cost | Lower | Higher |
| Use case | Sandbox / learning | Production-like testing |

## Cleanup

```bash
terraform destroy
```

> Redshift clusters can take 5–10 minutes to provision and destroy.
