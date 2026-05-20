# Terraform Templates

Terraform equivalents of the CloudFormation templates in [cloudformation-templates-ps](../cloudformation-templates-ps). Each module is self-contained and deploys to the AWS default VPC.

## Modules

| Module | Description | Region |
|--------|-------------|--------|
| [`ec2-only/`](ec2-only/) | Single EC2 instance (AL2023, gp3, EC2 Instance Connect) | us-east-1 |
| [`rds-mysql/`](rds-mysql/) | RDS MySQL, Secrets Manager, public access | us-east-1 / us-west-2 |
| [`rds-postgres/`](rds-postgres/) | RDS PostgreSQL, Secrets Manager, public access | us-east-1 |
| [`alb-only/`](alb-only/) | Application Load Balancer with optional HTTPS | us-east-1 / us-west-2 |
| [`ec2-mysql-alb/`](ec2-mysql-alb/) | EC2 + RDS MySQL + ALB (SSH key pair required) | us-east-1 / us-west-2 |
| [`ec2-postgres-alb/`](ec2-postgres-alb/) | EC2 + RDS PostgreSQL + ALB (EC2 Instance Connect) | us-east-1 |
| [`redshift-postgres-single-node/`](redshift-postgres-single-node/) | Redshift single-node + PostgreSQL RDS | us-east-1 / us-west-2 |
| [`redshift-postgres-two-nodes/`](redshift-postgres-two-nodes/) | Redshift two-node cluster + PostgreSQL RDS | us-east-1 / us-west-2 |
| [`eks-rds-postgres/`](eks-rds-postgres/) | EKS cluster + managed node group + RDS PostgreSQL | us-east-1 |

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/downloads) >= 1.0
- [AWS CLI](https://aws.amazon.com/cli/) v2 configured with credentials (`aws configure`)
- AWS account with a default VPC in the target region

## General Workflow

Every module follows the same four commands:

```bash
cd <module-name>

# 1. Download providers and initialize
terraform init

# 2. Preview what will be created
terraform plan

# 3. Deploy
terraform apply

# 4. Destroy when done
terraform destroy
```

To override any default variable without editing files:

```bash
terraform apply -var="name_prefix=myapp" -var="ec2_instance_type=t3.small"
```

Or create a `terraform.tfvars` file in the module directory:

```hcl
name_prefix       = "myapp"
ec2_instance_type = "t3.small"
```

## Retrieving Secrets Manager Passwords

All database modules store the generated password in AWS Secrets Manager. Retrieve it with:

```bash
aws secretsmanager get-secret-value \
  --secret-id <secret-name> \
  --query SecretString \
  --output text | jq -r '.password'
```

The secret name is shown in the `terraform output` after apply.

## Sandbox Limits

These templates are designed for sandbox/learning environments and respect the following constraints:

| Resource | Limit |
|----------|-------|
| EC2 | t2/t3/t3a micro\|small\|medium, default tenancy |
| RDS | db.t3/t4g micro\|small\|medium, max 50 GB, no provisioned IOPS |
| EBS | max 30 GB (EC2 root), max 50 GB (RDS) |
| EKS nodes | t2/t3/t3a micro\|small\|medium, max 2 nodes, max 30 GB disk |
| Redshift | ra3.large, max 2 nodes |

## CloudFormation Equivalence

| CloudFormation template | Terraform module |
|------------------------|-----------------|
| `ec2-only.yaml` | `ec2-only/` |
| `rds-mysql.yaml` | `rds-mysql/` |
| `rds-postgres.yaml` | `rds-postgres/` |
| `alb-only.yaml` | `alb-only/` |
| `ec2-mysql-alb.yaml` | `ec2-mysql-alb/` |
| `ec2-postgres-alb.yaml` | `ec2-postgres-alb/` |
| `eks-cluster.yaml` | `eks-rds-postgres/` |
| `redshift-postgres-single-node.yaml` | `redshift-postgres-single-node/` |
| `redshift-postgres-two-nodes.yaml` | `redshift-postgres-two-nodes/` |

Key translation decisions:
- **Lambda custom resources** (VPC lookup) → `data "aws_vpc"` + `data "aws_subnets"`
- **Secrets Manager auto-generated passwords** → `random_password` + `aws_secretsmanager_secret`
- **SSM AMI dynamic references** → `data "aws_ssm_parameter"`
- **CloudFormation stack name** → `var.name_prefix`
