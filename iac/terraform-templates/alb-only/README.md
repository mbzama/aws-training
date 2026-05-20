# ALB Only

Application Load Balancer with a target group and HTTP listener. Optionally adds an HTTPS listener with an ACM certificate.

Equivalent to CloudFormation template: `alb-only.yaml`

## What It Creates

- Application Load Balancer (internet-facing or internal)
- Target group (attach EC2 instances or an Auto Scaling group after deploy)
- HTTP listener on port 80 (forwards to target group, or redirects to HTTPS)
- HTTPS listener on port 443 (optional — requires an ACM certificate)
- Security group allowing HTTP (80) and HTTPS (443) from anywhere

## Prerequisites

- Terraform >= 1.0
- AWS CLI configured (`aws configure`)
- Default VPC with at least 2 subnets in different AZs (ALB requirement)
- ACM certificate in the same region (only if `enable_https = true`)

## Usage

### HTTP only (default)

```bash
terraform init
terraform apply
```

### With HTTPS

```hcl
# terraform.tfvars
enable_https    = true
certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/abc-123"
```

```bash
terraform apply
```

### Internal ALB

```hcl
# terraform.tfvars
alb_scheme = "internal"
```

## Variables

| Name | Default | Description |
|------|---------|-------------|
| `aws_region` | `us-east-1` | Deploy region |
| `name_prefix` | `alb-practice` | Prefix for resource names |
| `vpc_id` | `""` | VPC ID (empty = use default VPC) |
| `subnet_ids` | `[]` | Subnet IDs (empty = use default VPC subnets) |
| `alb_scheme` | `internet-facing` | `internet-facing` or `internal` |
| `enable_https` | `false` | Enable HTTPS listener on port 443 |
| `certificate_arn` | `""` | ACM certificate ARN (required when HTTPS enabled) |
| `target_port` | `80` | Port your backend instances listen on |
| `health_check_path` | `/` | ALB health check path |

## Outputs

| Name | Description |
|------|-------------|
| `alb_dns_name` | ALB DNS name (use in browser or DNS record) |
| `alb_arn` | ALB ARN |
| `target_group_arn` | Target Group ARN (register instances here) |
| `alb_security_group_id` | ALB Security Group ID |
| `alb_hosted_zone_id` | ALB Hosted Zone ID (for Route 53 alias records) |

## Register an EC2 Instance

After the ALB is created, register an existing EC2 instance with the target group:

```bash
TG_ARN=$(terraform output -raw target_group_arn)
aws elbv2 register-targets \
  --target-group-arn "$TG_ARN" \
  --targets Id=i-0123456789abcdef0,Port=80
```

## Cleanup

```bash
terraform destroy
```
