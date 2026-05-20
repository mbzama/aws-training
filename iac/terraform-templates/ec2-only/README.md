# EC2 Only

Single EC2 instance in the default VPC. Connects via **EC2 Instance Connect** — no key pair required.

Equivalent to CloudFormation template: `ec2-only.yaml`

## What It Creates

- EC2 instance (Amazon Linux 2023, gp3 storage)
- Security group allowing SSH (22) and HTTP (80)
- Apache HTTPD with an instance metadata page at `/`

## Prerequisites

- Terraform >= 1.0
- AWS CLI configured (`aws configure`)
- Default VPC with subnets in `us-east-1a` and `us-east-1b`

## Usage

```bash
terraform init
terraform apply
```

After apply, open the HTTP URL from the output in your browser, or click the EC2 Instance Connect URL to open a browser terminal.

## Variables

| Name | Default | Description |
|------|---------|-------------|
| `aws_region` | `us-east-1` | Deploy region (us-east-1 required for AZ filtering) |
| `name_prefix` | `ec2-practice` | Prefix for resource names |
| `ec2_instance_type` | `t3.medium` | Allowed: t2/t3/t3a micro\|small\|medium |
| `volume_size` | `30` | Root EBS volume size in GB (8–30) |

## Outputs

| Name | Description |
|------|-------------|
| `default_vpc_id` | Auto-detected default VPC ID |
| `ec2_instance_id` | EC2 Instance ID |
| `ec2_public_ip` | EC2 public IP address |
| `ec2_connect_url` | AWS Console EC2 Instance Connect URL |
| `http_url` | HTTP URL of the web page |

## Connecting

**EC2 Instance Connect (browser terminal):**
Open the `ec2_connect_url` output link in the AWS Console → click **Connect**.

**HTTP page:**
```bash
curl $(terraform output -raw http_url)
```

## Cleanup

```bash
terraform destroy
```
