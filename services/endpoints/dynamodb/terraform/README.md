# DynamoDB VPC Gateway Endpoint — Terraform POC

Demonstrates how to route EC2-to-DynamoDB traffic entirely within the AWS private network using a **VPC Gateway Endpoint**, with a Flask web app to interactively create, read, scan, and delete items.

---

## Architecture

```
  User/Browser
      │
      │  ① HTTP :5000  (public internet)
      ▼
  ┌── AWS Cloud (us-east-1) ─────────────────────────────────────────────────┐
  │  ┌── VPC: dynamodb-poc-vpc  10.0.0.0/16 ────────────────────────────┐   │
  │  │                                                                    │   │
  │  │  [Internet Gateway]                                                │   │
  │  │       │  ② port 5000                                              │   │
  │  │  ┌── Public Subnet  10.0.1.0/24 ──────────────────────────────┐  │   │
  │  │  │                                                              │  │   │
  │  │  │  [EC2 t2.micro]  ←──── [Security Group :22/:5000]          │  │   │
  │  │  │       │  ╰── [IAM Role] (no static keys)                   │  │   │
  │  │  │  [Flask App :5000]                                          │  │   │
  │  │  │       │  ③ boto3 DynamoDB API                               │  │   │
  │  │  └───────┼──────────────────────────────────────────────────── ┘  │   │
  │  │          │                                                         │   │
  │  │  [Route Table]  ④ DynamoDB prefix list  [VPC Gateway Endpoint]    │   │
  │  │                 Endpoint policy: allow only                        │   │
  │  │                 this specific table        │  ⑤ private network   │   │
  │  └────────────────────────────────────────────┼──────────────────────┘   │
  │                                               ▼                          │
  │                                      [DynamoDB Table]                    │
  └──────────────────────────────────────────────────────────────────────────┘
```

---

## How it works

### What is a VPC Gateway Endpoint?

A VPC Gateway Endpoint is a horizontally scaled, redundant AWS-managed gateway that lets resources inside a VPC reach DynamoDB (or S3) **without traversing the public internet**. It is free — there is no per-hour or per-GB charge.

When the endpoint is attached to a route table, AWS automatically adds a route for the DynamoDB prefix list (e.g. `pl-02cd2c6b`) pointing to the endpoint ID. Any traffic destined for DynamoDB from that subnet is intercepted and routed internally.

### Request flow

| Step | Traffic path |
|------|-------------|
| Browser submits a form | Browser → Internet → EC2 `:5000` (via IGW) |
| Flask calls `table.put_item()` | EC2 → Route Table → VPC Gateway Endpoint → DynamoDB |
| Flask returns response | DynamoDB → Endpoint → EC2 → Internet → Browser |

DynamoDB traffic **never leaves the AWS network**. The IGW only carries the browser↔EC2 HTTP connection.

### Endpoint policy

The VPC endpoint has a **resource-scoped policy** that restricts traffic through the endpoint to only the specific DynamoDB table created by this POC:

```json
{
  "Statement": [{
    "Effect": "Allow",
    "Principal": "*",
    "Action": "dynamodb:*",
    "Resource": "arn:aws:dynamodb:us-east-1:<account_id>:table/dynamodb-vpc-endpoint-poc"
  }]
}
```

This means any traffic going through this endpoint can only access our specific table — not any other DynamoDB table in any AWS account. This is analogous to the S3 bucket policy used in the S3 gateway endpoint POC.

---

## Infrastructure created

| Resource | Name | Details |
|----------|------|---------|
| VPC | `dynamodb-poc-vpc` | `10.0.0.0/16`, DNS hostnames enabled |
| Subnet | `dynamodb-poc-public-subnet` | `10.0.1.0/24`, public IPs auto-assigned |
| Internet Gateway | `dynamodb-poc-igw` | Attached to VPC |
| Route Table | `dynamodb-poc-public-rt` | `0.0.0.0/0 → IGW` + DynamoDB endpoint route |
| Security Group | `dynamodb-poc-sg` | Inbound: SSH `:22`, Flask `:5000` |
| IAM Role | `dynamodb-poc-ec2-dynamodb-role` | EC2 assume role, DynamoDB table access |
| IAM Instance Profile | `dynamodb-poc-instance-profile` | Attached to EC2 |
| EC2 Instance | `dynamodb-poc-ec2` | Amazon Linux 2023, Flask via systemd |
| DynamoDB Table | `dynamodb-vpc-endpoint-poc` | PAY_PER_REQUEST, partition key: `id` (String) |
| VPC Gateway Endpoint | `dynamodb-poc-dynamodb-endpoint` | Gateway type, wired to public route table |

---

## Prerequisites

- Terraform >= 1.3
- AWS CLI configured (`aws configure`)
- An existing EC2 key pair in your target region

---

## Quick start

```bash
# 1. Copy and fill in your values
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` — only two values are required:

```hcl
key_pair_name = "your-key-pair"   # EC2 key pair name (no .pem extension)
table_name    = "dynamodb-vpc-endpoint-poc"
```

```bash
# 2. Initialise providers
terraform init

# 3. Preview changes
terraform plan

# 4. Deploy (approx. 2 min)
terraform apply

# 5. Open the app URL from outputs
# Wait 4-5 minutes for EC2 user_data to install Flask and start the service
```

### Outputs after apply

```
app_url              = "http://<EC2_IP>:5000"
ssh_command          = "ssh -i your-key.pem ec2-user@<EC2_IP>"
dynamodb_table_name  = "dynamodb-vpc-endpoint-poc"
vpc_id               = "vpc-XXXXXXXXXXXXXXXXX"
vpc_endpoint_id      = "vpce-XXXXXXXXXXXXXXXXX"
verify_route_table   = "VPC -> Route Tables -> rtb-XXXX -> Routes tab -> look for pl-XXXXX -> vpce-XXXXX"
```

---

## Using the Flask app

Open `http://<EC2_IP>:5000` in your browser.

| Action | What happens |
|--------|-------------|
| **Create Item** | Enter a title and value, click "Create Item" — Flask calls `table.put_item()` via the endpoint |
| **Scan All Items** | Click "Scan All Items" — Flask calls `table.scan()`, results shown in a table |
| **Get** | Click "Get" next to any item — Flask calls `table.get_item()` for that specific item |
| **Delete** | Click "Delete" next to any item — Flask calls `table.delete_item()` and refreshes the list |
| **Response log** | Every operation logs the response time (ms), operation type, and success/error status |

The response log shows **single-digit millisecond** response times — characteristic of traffic routed entirely within the AWS network with no internet round-trip.

---

## Verify the endpoint is routing traffic

### 1. Check the route table in the AWS console

```
VPC → Route Tables → dynamodb-poc-public-rt → Routes tab
```

You should see a route like:

| Destination | Target |
|-------------|--------|
| `10.0.0.0/16` | local |
| `0.0.0.0/0` | igw-XXXXXXXX |
| `pl-02cd2c6b` (DynamoDB prefix list) | vpce-XXXXXXXX |

### 2. SSH and test from EC2

```bash
ssh -i your-key.pem ec2-user@<EC2_IP>

# Verify Flask is running
sudo systemctl status dynamodb-poc

# Scan table (goes via the endpoint — should succeed)
aws dynamodb scan --table-name dynamodb-vpc-endpoint-poc --region us-east-1

# Check Flask logs
sudo journalctl -u dynamodb-poc -f

# Check user_data install logs
sudo cat /var/log/userdata.log
```

### 3. Verify the endpoint policy restricts table access

From EC2, try accessing a table that is **not** in the endpoint policy:

```bash
# This should fail — the endpoint policy only allows our specific table
aws dynamodb list-tables --region us-east-1
# Expected: An error occurred (AccessDeniedException) ...
```

---

## DynamoDB vs S3 gateway endpoints

| Feature | S3 | DynamoDB |
|---------|-----|---------|
| Endpoint type | Gateway | Gateway |
| Cost | Free | Free |
| Resource policy | S3 bucket policy (deny outside VPCE) | Endpoint policy (restrict to specific table) |
| Prefix list | `pl-63a5400a` (us-east-1) | `pl-02cd2c6b` (us-east-1) |
| IAM required | Yes | Yes |

Both are **Gateway** type endpoints, unlike Interface endpoints (PrivateLink) which have per-hour and per-GB charges.

---

## File structure

```
dynamodb/terraform/
├── main.tf                   # VPC, subnets, EC2, DynamoDB, IAM, endpoint
├── variables.tf              # Input variable declarations
├── outputs.tf                # Post-apply output values
├── userdata.sh               # EC2 bootstrap: installs Flask, writes app, starts systemd service
├── terraform.tfvars          # Your values (git-ignored)
├── terraform.tfvars.example  # Template — copy to terraform.tfvars
└── README.md
```

---

## Clean up

```bash
terraform destroy
```

Terraform will delete all resources including the DynamoDB table and all its items.
