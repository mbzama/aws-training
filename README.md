# AWS Training

A collection of hands-on AWS architecture examples using Terraform, EKS, API Gateway, CloudFront, Glue, DMS, and more.

## Repository Layout

| Folder | Summary |
|--------|---------|
| [`iac/`](./iac) | Infrastructure as Code — CloudFormation and Terraform templates for EC2, RDS, EKS, ALB, and Redshift |
| [`apps/`](./apps) | Web and microservice application projects — Next.js, NestJS, React apps deployed on EKS, S3, Amplify, and API Gateway |
| [`data-engineering/`](./data-engineering) | Data pipeline projects — AWS DMS migration labs and AWS Glue ETL jobs (medallion architecture, multi-source connections) |
| [`services/`](./services) | Backend service examples — AWS Secrets Manager integration across Node, Python, and Java runtimes on EKS |
| [`ai-ml/`](./ai-ml) | AI/ML examples on AWS (in progress) |

---

## Spinning Up Resources

Before running the application projects below, you need AWS infrastructure (EC2, RDS, EKS, etc.). Two options are available — CloudFormation and Terraform — covering the same set of stacks.

### CloudFormation Templates → [`iac/cloudformation-templates/`](./iac/cloudformation-templates)

| Template | Resources |
|----------|-----------|
| `alb-only.yaml` | ALB in the default VPC |
| `ec2-only.yaml` | Single EC2 instance |
| `ec2-mysql-alb.yaml` | EC2 + MySQL RDS + ALB |
| `ec2-postgres-alb.yaml` | EC2 + PostgreSQL RDS + ALB |
| `rds-mysql.yaml` | MySQL RDS (standalone) |
| `rds-postgres.yaml` | PostgreSQL RDS (standalone) |
| `eks-cluster.yaml` | EKS cluster + VPC + managed node group |
| `redshift-postgres-single-node.yaml` | Redshift (single node) + PostgreSQL RDS |
| `redshift-postgres-two-nodes.yaml` | Redshift (two nodes) + PostgreSQL RDS |

**Deploy (CLI):**
```bash
aws cloudformation create-stack \
  --stack-name <stack-name> \
  --template-body file://<template-file> \
  --region us-east-1 \
  --capabilities CAPABILITY_NAMED_IAM
```

See [`iac/cloudformation-templates/README.md`](./iac/cloudformation-templates/README.md) for console instructions, output values, and EKS connection steps.

---

### Terraform Templates → [`iac/terraform-templates/`](./iac/terraform-templates)

| Module | Resources | Region |
|--------|-----------|--------|
| [`ec2-only/`](./iac/terraform-templates/ec2-only) | Single EC2 instance | us-east-1 |
| [`rds-mysql/`](./iac/terraform-templates/rds-mysql) | RDS MySQL + Secrets Manager | us-east-1 / us-west-2 |
| [`rds-postgres/`](./iac/terraform-templates/rds-postgres) | RDS PostgreSQL + Secrets Manager | us-east-1 |
| [`alb-only/`](./iac/terraform-templates/alb-only) | Application Load Balancer | us-east-1 / us-west-2 |
| [`ec2-mysql-alb/`](./iac/terraform-templates/ec2-mysql-alb) | EC2 + RDS MySQL + ALB | us-east-1 / us-west-2 |
| [`ec2-postgres-alb/`](./iac/terraform-templates/ec2-postgres-alb) | EC2 + RDS PostgreSQL + ALB | us-east-1 |
| [`redshift-postgres-single-node/`](./iac/terraform-templates/redshift-postgres-single-node) | Redshift single-node + PostgreSQL RDS | us-east-1 / us-west-2 |
| [`redshift-postgres-two-nodes/`](./iac/terraform-templates/redshift-postgres-two-nodes) | Redshift two-node cluster + PostgreSQL RDS | us-east-1 / us-west-2 |
| [`eks-rds-postgres/`](./iac/terraform-templates/eks-rds-postgres) | EKS cluster + managed node group + RDS PostgreSQL | us-east-1 |

**Deploy:**
```bash
cd iac/terraform-templates/<module-name>
terraform init
terraform plan
terraform apply
# when done:
terraform destroy
```

See [`iac/terraform-templates/README.md`](./iac/terraform-templates/README.md) for variable overrides, sandbox limits, and Secrets Manager password retrieval.

---

## Apps

Web and microservice application projects. Each project has its own README with deployment instructions.

| Project | Key AWS Services |
|---------|-----------------|
| [api-gateway-lambda-authorizer](#api-gateway-lambda-authorizer) | API Gateway, Lambda, IAM |
| [apigateway-cdn-s3-nextjs](#apigateway-cdn-s3-nextjs) | API Gateway, CloudFront, S3 |
| [aws-amplify-reactjs](#aws-amplify-reactjs) | Amplify, ACM |
| [aws-cdn-s3-spa-multiple-folders](#aws-cdn-s3-spa-multiple-folders) | CloudFront, S3, ACM |
| [eks-2-apigateway-traefik-nlb](#eks-2-apigateway-traefik-nlb) | EKS, API Gateway, NLB, Traefik |
| [eks-apigateway-traefik-nlb](#eks-apigateway-traefik-nlb) | EKS, API Gateway, NLB, Traefik |
| [eks-traefik](#eks-traefik) | EKS, NLB, Traefik |
| [mock-web](#mock-web) | Next.js, Docker |
| [nlb-traefik-ingress-nestjs](#nlb-traefik-ingress-nestjs) | EKS, NLB, Traefik, ACM |

---

### [api-gateway-lambda-authorizer](./apps/api-gateway-lambda-authorizer)

A JWT Bearer token Lambda Authorizer for API Gateway HTTP API. Validates JWT tokens (signature, expiry, issuer, audience, scopes) and returns IAM policies to allow or deny access. Decoded claims are forwarded to backend Lambda functions via request context.

**Stack:** API Gateway v2 · Lambda · IAM · CloudWatch

---

### [apigateway-cdn-s3-nextjs](./apps/apigateway-cdn-s3-nextjs)

A Next.js e-commerce app exported as static files, hosted on S3, and served through CloudFront with SPA routing via a CloudFront Function. API Gateway acts as the public entry point with a custom domain backed by an ACM certificate.

**Stack:** API Gateway v2 · CloudFront · S3 · ACM · CloudFront Functions · Terraform

---

### [aws-amplify-reactjs](./apps/aws-amplify-reactjs)

A React application deployed to AWS Amplify with a custom domain and HTTPS. Amplify handles CI/CD from a Git branch; Terraform provisions the Amplify app, branch, and ACM certificate.

**Stack:** AWS Amplify · ACM · Terraform

---

### [aws-cdn-s3-spa-multiple-folders](./apps/aws-cdn-s3-spa-multiple-folders)

Three independently deployable micro-frontend SPAs (landing, movies, users) built with Module Federation and single-spa. All apps are served from a single S3 bucket behind CloudFront with path-based routing and deep-link rewriting via a CloudFront Function.

**Stack:** CloudFront · S3 · ACM · CloudFront Functions · Module Federation · Terraform

---

### [eks-2-apigateway-traefik-nlb](./apps/eks-2-apigateway-traefik-nlb)

Two NestJS microservices (external-api and internal-api) deployed on EKS, routed through Traefik ingress, and exposed publicly via API Gateway v2 over a private VPC Link to an internal NLB. Demonstrates host-based and path-based routing with TLS.

**Stack:** EKS · API Gateway v2 · NLB · Traefik · VPC Link · ACM · Terraform

---

### [eks-apigateway-traefik-nlb](./apps/eks-apigateway-traefik-nlb)

A NestJS mock API and Next.js UI deployed on EKS, routed through Traefik, and exposed via API Gateway v2 over a VPC Link. Supports a custom domain with ACM and separate path prefixes (`/mock` for API, `/web` for UI).

**Stack:** EKS · API Gateway v2 · NLB · Traefik · VPC Link · ACM · Terraform

---

### [eks-traefik](./apps/eks-traefik)

A NestJS API and Next.js UI deployed on EKS with Traefik as the ingress controller, exposed through an internet-facing NLB with ACM TLS termination. No API Gateway — traffic goes directly NLB → Traefik → service.

**Stack:** EKS · NLB · Traefik · ACM · Terraform

---

### [mock-web](./apps/mock-web)

A reusable Next.js e-commerce UI (products and cart) used as the frontend component across multiple EKS-based projects. Includes a Dockerfile for containerised deployment and a deploy script targeting ECR.

**Stack:** Next.js · TypeScript · Tailwind CSS · Docker

---

### [nlb-traefik-ingress-nestjs](./apps/nlb-traefik-ingress-nestjs)

A Next.js frontend and NestJS API deployed on EKS, routed through Traefik ingress, and exposed via an internet-facing NLB with ACM TLS termination. Demonstrates internal service-to-service communication alongside external traffic routing.

**Stack:** EKS · NLB · Traefik · ACM · NestJS · Next.js · Terraform

---

## Data Engineering

Data pipeline and ETL projects using AWS DMS and AWS Glue.

| Project | Description |
|---------|-------------|
| [aws-dms-demos/same-account-vpc](./data-engineering/aws-dms-demos/same-account-vpc) | Same-VPC DMS migration between two PostgreSQL RDS instances; includes a Python script to seed the source database |
| [glue-jobs/data-connections-spread](./data-engineering/glue-jobs/data-connections-spread) | Glue job demonstrating connections to Redshift and RDS via Lambda-triggered orchestration |
| [glue-jobs/medallion-demo](./data-engineering/glue-jobs/medallion-demo) | Glue PySpark pipeline implementing Bronze → Silver → Gold medallion architecture on S3, orchestrated by a Glue Workflow |
| [glue-jobs-demo/medallion-demo](./data-engineering/glue-jobs-demo/medallion-demo) | CloudFormation + Terraform variant of the medallion Glue demo with an IP waiter Lambda for VPC readiness |

---

## Services

Backend service examples demonstrating how to fetch secrets from AWS Secrets Manager at runtime using IRSA on EKS.

| Runtime | Path |
|---------|------|
| Next.js | [services/aws-secrets-manager/nextjs](./services/aws-secrets-manager/nextjs) |
| NestJS | [services/aws-secrets-manager/nestjs](./services/aws-secrets-manager/nestjs) |
| Express.js | [services/aws-secrets-manager/expressjs](./services/aws-secrets-manager/expressjs) |
| FastAPI (Python) | [services/aws-secrets-manager/fast-api](./services/aws-secrets-manager/fast-api) |
| Spring Boot (Java) | [services/aws-secrets-manager/spring-boot](./services/aws-secrets-manager/spring-boot) |
