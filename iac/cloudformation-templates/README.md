# CloudFormation Templates - Quick Start

This folder contains CloudFormation templates for common sandbox stacks (EC2, RDS, ALB, EKS, Redshift). Use the CLI or the CloudFormation console to deploy.

## Templates
- alb-only.yaml: ALB in the default VPC.
- ec2-only.yaml: EC2 instance in the default VPC.
- ec2-mysql-alb.yaml: EC2 + MySQL RDS + ALB.
- ec2-postgres-alb.yaml: EC2 + PostgreSQL RDS + ALB.
- rds-mysql.yaml: MySQL RDS (standalone).
- rds-postgres.yaml: PostgreSQL RDS (standalone).
- eks-cluster.yaml: EKS cluster, VPC, subnets, NATs, managed node group, addons.
- redshift-postgres-single-node.yaml: Redshift (single node) + PostgreSQL RDS.
- redshift-postgres-two-nodes.yaml: Redshift (two nodes) + PostgreSQL RDS.

## Deploy via AWS CLI
1) Pick a template file.
2) Run one of the commands below (create or update).

Create a new stack:
```bash
aws cloudformation create-stack \
  --stack-name <stack-name> \
  --template-body file://<template-file> \
  --region <region> \
  --capabilities CAPABILITY_NAMED_IAM
```

Update an existing stack:
```bash
aws cloudformation update-stack \
  --stack-name <stack-name> \
  --template-body file://<template-file> \
  --region <region> \
  --capabilities CAPABILITY_NAMED_IAM
```

Notes:
- Use `CAPABILITY_NAMED_IAM` because these templates create IAM roles.
- Some templates are intended for us-east-1 only (see each template description).

## Deploy via CloudFormation Console
1) Go to AWS Console -> CloudFormation -> Stacks -> Create stack -> With new resources.
2) Choose "Upload a template file" and select the YAML file.
3) Click Next, set the stack name and parameters, then Next.
4) On the "Configure stack options" page, keep defaults or add tags.
5) On the "Review" page, check "I acknowledge that AWS CloudFormation might create IAM resources".
6) Click Create stack.

## Access Resources in AWS Console
All stacks expose key values in Outputs. After deployment:
- Open CloudFormation -> Stacks -> select your stack -> Outputs.
- Use the output values to connect to services (endpoints, ARNs, DNS names).

### EC2 Instances (ec2-only.yaml, ec2-mysql-alb.yaml, ec2-postgres-alb.yaml)
- Console path: EC2 -> Instances.
- Use the Instance ID from Outputs to find it quickly.
- For EC2 Instance Connect: EC2 -> Instances -> select instance -> Connect.

### Application Load Balancer (alb-only.yaml, ec2-mysql-alb.yaml, ec2-postgres-alb.yaml)
- Console path: EC2 -> Load Balancers.
- Open the DNS name from Outputs in your browser.

### RDS (rds-mysql.yaml, rds-postgres.yaml, ec2-mysql-alb.yaml, ec2-postgres-alb.yaml)
- Console path: RDS -> Databases.
- Use the endpoint from Outputs to connect.
- Passwords are stored in Secrets Manager (see below).

### Secrets Manager (passwords)
- Console path: Secrets Manager -> Secrets.
- Look for secrets created by your stack (Outputs include secret ARN/name in most templates).
- Retrieve the password from the secret value.

### EKS Cluster (eks-cluster.yaml)
- Console path: EKS -> Clusters.
- Use the ClusterName output to locate the cluster.
- For node group: EKS -> Clusters -> <cluster> -> Compute -> Node groups.
- Addons: EKS -> Clusters -> <cluster> -> Add-ons.

## Connect to EKS Cluster from Local Machine

### Prerequisites
Before connecting to your EKS cluster, ensure you have:
1. **AWS CLI** installed and configured:
   ```bash
   aws --version
   aws configure
   ```
2. **kubectl** installed (Kubernetes command-line tool):
   ```bash
   # macOS (Homebrew)
   brew install kubectl
   
   # Linux
   curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
   chmod +x kubectl
   sudo mv kubectl /usr/local/bin/
   
   # Windows (Chocolatey)
   choco install kubernetes-cli
   ```
3. **IAM permissions** to access EKS (eks:DescribeCluster at minimum).

### Configure kubectl
After deploying eks-cluster.yaml, get the KubeconfigCommand from CloudFormation Outputs:

```bash
# Get the command from stack outputs
aws cloudformation describe-stacks \
  --stack-name <your-stack-name> \
  --query "Stacks[0].Outputs[?OutputKey=='KubeconfigCommand'].OutputValue" \
  --output text

# Example output:
# aws eks update-kubeconfig --region us-east-1 --name hrms-cluster
```

Run the command to configure kubectl:
```bash
aws eks update-kubeconfig --region us-east-1 --name hrms-cluster
```

This adds a new context to your `~/.kube/config` file.

### Verify Connection
Check cluster connectivity:
```bash
# View cluster info
kubectl cluster-info

# List nodes
kubectl get nodes

# Check node status and details
kubectl get nodes -o wide

# View all resources in all namespaces
kubectl get all --all-namespaces
```

### Common kubectl Commands
```bash
# Get cluster information
kubectl config get-contexts                    # List all contexts
kubectl config current-context                 # Show current context
kubectl config use-context <context-name>      # Switch context

# View cluster resources
kubectl get pods                              # List pods in default namespace
kubectl get pods -n kube-system               # List pods in kube-system namespace
kubectl get services                          # List services
kubectl get deployments                       # List deployments
kubectl get namespaces                        # List namespaces

# Describe resources
kubectl describe node <node-name>             # Node details
kubectl describe pod <pod-name>               # Pod details

# Create/deploy applications
kubectl create namespace <namespace>          # Create namespace
kubectl apply -f <manifest.yaml>             # Deploy from YAML
kubectl delete -f <manifest.yaml>            # Delete resources from YAML

# View logs
kubectl logs <pod-name>                      # View pod logs
kubectl logs -f <pod-name>                   # Stream pod logs
kubectl logs <pod-name> -c <container>       # Logs from specific container

# Execute commands in pods
kubectl exec -it <pod-name> -- /bin/bash     # Interactive shell
kubectl exec <pod-name> -- <command>         # Run command

# Port forwarding
kubectl port-forward <pod-name> 8080:80      # Forward local port to pod
kubectl port-forward service/<svc> 8080:80   # Forward local port to service
```

### Troubleshooting EKS Connection
**Error: "You must be logged in to the server (Unauthorized)"**
- Your AWS credentials don't have EKS permissions.
- Solution: Add eks:DescribeCluster permission to your IAM user/role.

**Error: "No resources found"**
- The cluster is empty (no workloads deployed yet).
- Solution: This is normal for a new cluster. Deploy an application.

**Error: "error: You must be logged in to the server (the server has asked for the client to provide credentials)"**
- AWS CLI is not configured or credentials expired.
- Solution: Run `aws configure` or refresh your AWS session.

**Checking EKS cluster authentication:**
```bash
# Test AWS CLI access to EKS
aws eks describe-cluster --name hrms-cluster --region us-east-1

# Verify IAM identity
aws sts get-caller-identity
```

### Redshift (redshift-postgres-single-node.yaml, redshift-postgres-two-nodes.yaml)
- Console path: Amazon Redshift -> Clusters.
- Use the cluster endpoint output for clients.

## Common Troubleshooting
- Stack stuck in CREATE_FAILED: open the stack -> Events to see the exact error.
- IAM errors: make sure you used `--capabilities CAPABILITY_NAMED_IAM`.
- Region limits: some templates are intended for us-east-1 only (check each template description).
