# S3 VPC Gateway Endpoint — Terraform POC

Demonstrates how to route EC2-to-S3 traffic entirely within the AWS private network using a **VPC Gateway Endpoint**, with a Flask web app to interactively upload, list, and download files.

---

## Architecture diagram

> **[Open architecture.drawio](./architecture.drawio)** in [draw.io](https://app.diagrams.net/) for the full interactive diagram with AWS icons.
>
> To open: drag the file onto [app.diagrams.net](https://app.diagrams.net/), or in VS Code install the **Draw.io Integration** extension and click the file.

The diagram shows the following topology:

```
  User/Browser
      │
      │  ① HTTP :5000  (public internet)
      ▼
  ┌── AWS Cloud (us-east-1) ─────────────────────────────────────────────────┐
  │  ┌── VPC: s3-poc-vpc  10.0.0.0/16 ──────────────────────────────────┐   │
  │  │                                                                    │   │
  │  │  [Internet Gateway]                                                │   │
  │  │       │  ② port 5000                                              │   │
  │  │  ┌── Public Subnet  10.0.1.0/24 ──────────────────────────────┐  │   │
  │  │  │                                                              │  │   │
  │  │  │  [EC2 t2.micro]  ←──── [Security Group :22/:5000]          │  │   │
  │  │  │       │  ╰── [IAM Role] (no static keys)                   │  │   │
  │  │  │  [Flask App :5000]                                          │  │   │
  │  │  │       │  ③ boto3 S3 API                                     │  │   │
  │  │  └───────┼──────────────────────────────────────────────────── ┘  │   │
  │  │          │                                                         │   │
  │  │  [Route Table]  ④ S3 prefix list  [VPC Gateway Endpoint]          │   │
  │  │                                          │  ⑤ private network     │   │
  │  └──────────────────────────────────────────┼──────────────────────── ┘  │
  │                                             ▼                            │
  │                                       [S3 Bucket]                        │
  │                                   Bucket Policy: DENY                    │
  │                                   without VPCE or EC2 role               │
  └──────────────────────────────────────────────────────────────────────────┘
```

---

## How it works

### What is a VPC Gateway Endpoint?

A VPC Gateway Endpoint is a horizontally scaled, redundant AWS-managed gateway that lets resources inside a VPC reach S3 (or DynamoDB) **without traversing the public internet**. It is free — there is no per-hour or per-GB charge.

When the endpoint is attached to a route table, AWS automatically adds a route for the S3 prefix list (e.g. `pl-63a5400a`) pointing to the endpoint ID. Any traffic destined for S3 from that subnet is intercepted and routed internally.

### Request flow

| Step | Traffic path |
|------|-------------|
| Browser uploads a file | Browser → Internet → EC2 `:5000` (via IGW) |
| Flask calls `s3.put_object()` | EC2 → Route Table → VPC Gateway Endpoint → S3 |
| Flask returns response | S3 → Endpoint → EC2 → Internet → Browser |

S3 data traffic **never leaves the AWS network**. The IGW only carries the browser↔EC2 HTTP connection.

### Why the bucket policy matters

The bucket policy has a **Deny** statement with two conditions joined by an implicit AND (both must be false for the deny to apply):

```
Deny s3:* to Principal=*
  UNLESS aws:sourceVpce == this endpoint
  OR aws:PrincipalArn == the EC2 IAM role
```

This means:
- Requests from the EC2 instance via the endpoint → **allowed**
- Requests from the AWS CLI on your laptop → **denied** (no endpoint)
- Requests from any other AWS account → **denied**

---

## Infrastructure created

| Resource | Name | Details |
|----------|------|---------|
| VPC | `s3-poc-vpc` | `10.0.0.0/16`, DNS hostnames enabled |
| Subnet | `s3-poc-public-subnet` | `10.0.1.0/24`, public IPs auto-assigned |
| Internet Gateway | `s3-poc-igw` | Attached to VPC |
| Route Table | `s3-poc-public-rt` | `0.0.0.0/0 → IGW` + S3 endpoint route |
| Security Group | `s3-poc-sg` | Inbound: SSH `:22`, Flask `:5000` |
| IAM Role | `s3-poc-ec2-s3-role` | EC2 assume role, S3 bucket access |
| IAM Instance Profile | `s3-poc-instance-profile` | Attached to EC2 |
| EC2 Instance | `s3-poc-ec2` | Amazon Linux 2023, Flask via systemd |
| S3 Bucket | `s3-vpc-endpoint-poc-2-<account_id>` | CORS, versioning off, deny-outside-endpoint policy |
| VPC Gateway Endpoint | `s3-poc-s3-endpoint` | Gateway type, wired to public route table |

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
bucket_name   = "s3-vpc-endpoint-poc"  # prefix — account ID appended automatically
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
app_url             = "http://<EC2_IP>:5000"
ssh_command         = "ssh -i your-key.pem ec2-user@<EC2_IP>"
s3_bucket_name      = "s3-vpc-endpoint-poc-<account_id>"
vpc_id              = "vpc-XXXXXXXXXXXXXXXXX"
vpc_endpoint_id     = "vpce-XXXXXXXXXXXXXXXXX"
verify_route_table  = "VPC -> Route Tables -> rtb-XXXX -> Routes tab -> look for pl-XXXXX -> vpce-XXXXX"
```

---

## Using the Flask app

Open `http://<EC2_IP>:5000` in your browser.

| Action | What happens |
|--------|-------------|
| **Upload** | Select an image, click "Upload to S3" — Flask calls `s3.put_object()` via the endpoint |
| **List** | Click "List objects" — Flask calls `s3.list_objects_v2()`, results shown in a table |
| **Download** | Click "Download" next to any file — Flask streams the object back via `s3.get_object()` |
| **Response log** | Every operation logs the response time (ms), operation type, and success/error status |

The response log lets you observe that all S3 operations complete in **single-digit to low-double-digit milliseconds** — characteristic of traffic routed entirely within the AWS network with no internet round-trip.

---

## Verify the endpoint is routing traffic

### 1. Check the route table in the AWS console

```
VPC → Route Tables → s3-poc-public-rt → Routes tab
```

You should see a route like:

| Destination | Target |
|-------------|--------|
| `10.0.0.0/16` | local |
| `0.0.0.0/0` | igw-XXXXXXXX |
| `pl-63a5400a` (S3 prefix list) | vpce-XXXXXXXX |

### 2. SSH and test from EC2

```bash
ssh -i your-key.pem ec2-user@<EC2_IP>

# Verify Flask is running
sudo systemctl status s3-poc

# List bucket objects (goes via the endpoint — should succeed)
aws s3 ls s3://<BUCKET_NAME> --region us-east-1

# Check Flask logs
sudo journalctl -u s3-poc -f

# Check user_data install logs
sudo cat /var/log/userdata.log
```

### 3. Verify the bucket policy blocks direct access

Run this from your **local machine** (not EC2). It should return an Access Denied error because your laptop does not go through the VPC endpoint:

```bash
aws s3 ls s3://<BUCKET_NAME>
# Expected: An error occurred (AccessDenied) ...
```

---

## File structure

```
s3/terraform/
├── main.tf                   # VPC, subnets, EC2, S3, IAM, endpoint
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

Terraform will delete all resources including the S3 bucket and its contents (`force_destroy = true`).
