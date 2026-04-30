# AWS Training

A collection of hands-on AWS architecture examples using Terraform, EKS, API Gateway, CloudFront, and more.

## Projects

| # | Project | Key AWS Services |
|---|---------|-----------------|
| 1 | [api-gateway-lambda-authorizer](#1-api-gateway-lambda-authorizer) | API Gateway, Lambda, IAM |
| 2 | [apigateway-cdn-s3-nextjs](#2-apigateway-cdn-s3-nextjs) | API Gateway, CloudFront, S3 |
| 3 | [aws-amplify-reactjs](#3-aws-amplify-reactjs) | Amplify, ACM |
| 4 | [aws-cdn-s3-spa-multiple-folders](#4-aws-cdn-s3-spa-multiple-folders) | CloudFront, S3, ACM |
| 5 | [aws-dms](#5-aws-dms) | DMS, RDS, VPC |
| 6 | [aws-dms-demos](#6-aws-dms-demos) | DMS, RDS, VPC |
| 7 | [aws-secrets-manager](#7-aws-secrets-manager) | Secrets Manager, EKS, IAM |
| 8 | [eks-2-apigateway-traefik-nlb](#8-eks-2-apigateway-traefik-nlb) | EKS, API Gateway, NLB, Traefik |
| 9 | [eks-apigateway-traefik-nlb](#9-eks-apigateway-traefik-nlb) | EKS, API Gateway, NLB, Traefik |
| 10 | [eks-traefik](#10-eks-traefik) | EKS, NLB, Traefik |
| 11 | [mock-web](#11-mock-web) | Next.js, Docker |
| 12 | [nlb-traefik-ingress-nestjs](#12-nlb-traefik-ingress-nestjs) | EKS, NLB, Traefik, ACM |

---

### 1. [api-gateway-lambda-authorizer](./api-gateway-lambda-authorizer)

A JWT Bearer token Lambda Authorizer for API Gateway HTTP API. Validates JWT tokens (signature, expiry, issuer, audience, scopes) and returns IAM policies to allow or deny access. Decoded claims are forwarded to backend Lambda functions via request context.

**Stack:** API Gateway v2 · Lambda · IAM · CloudWatch

---

### 2. [apigateway-cdn-s3-nextjs](./apigateway-cdn-s3-nextjs)

A Next.js e-commerce app exported as static files, hosted on S3, and served through CloudFront with SPA routing via a CloudFront Function. API Gateway acts as the public entry point with a custom domain backed by an ACM certificate.

**Stack:** API Gateway v2 · CloudFront · S3 · ACM · CloudFront Functions · Terraform

---

### 3. [aws-amplify-reactjs](./aws-amplify-reactjs)

A React application deployed to AWS Amplify with a custom domain and HTTPS. Amplify handles CI/CD from a Git branch; Terraform provisions the Amplify app, branch, and ACM certificate.

**Stack:** AWS Amplify · ACM · Terraform

---

### 4. [aws-cdn-s3-spa-multiple-folders](./aws-cdn-s3-spa-multiple-folders)

Three independently deployable micro-frontend SPAs (landing, movies, users) built with Module Federation and single-spa. All apps are served from a single S3 bucket behind CloudFront with path-based routing and deep-link rewriting via a CloudFront Function.

**Stack:** CloudFront · S3 · ACM · CloudFront Functions · Module Federation · Terraform

---

### 5. [aws-dms](./aws-dms)

A Terraform lab that provisions two PostgreSQL RDS instances (source and destination) and a DMS replication instance to practice full-load and CDC (Change Data Capture) database migrations.

**Stack:** DMS · RDS (PostgreSQL) · VPC · IAM · Terraform

---

### 6. [aws-dms-demos](./aws-dms-demos)

Same-account VPC variant of the DMS lab. Demonstrates DMS migration between two PostgreSQL instances within the same VPC, including a Python script to populate the source database with test data.

**Stack:** DMS · RDS (PostgreSQL) · VPC · IAM · CloudWatch · Terraform

---

### 7. [aws-secrets-manager](./aws-secrets-manager)

A Next.js application that fetches secrets from AWS Secrets Manager at runtime using IRSA (IAM Roles for Service Accounts). Includes a Helm chart for Kubernetes deployment with an init container pattern for secret injection.

**Stack:** Secrets Manager · EKS · IAM · IRSA · Helm · Docker

---

### 8. [eks-2-apigateway-traefik-nlb](./eks-2-apigateway-traefik-nlb)

Two NestJS microservices (external-api and internal-api) deployed on EKS, routed through Traefik ingress, and exposed publicly via API Gateway v2 over a private VPC Link to an internal NLB. Demonstrates host-based and path-based routing with TLS.

**Stack:** EKS · API Gateway v2 · NLB · Traefik · VPC Link · ACM · Terraform

---

### 9. [eks-apigateway-traefik-nlb](./eks-apigateway-traefik-nlb)

A NestJS mock API and Next.js UI deployed on EKS, routed through Traefik, and exposed via API Gateway v2 over a VPC Link. Supports a custom domain with ACM and separate path prefixes (`/mock` for API, `/web` for UI).

**Stack:** EKS · API Gateway v2 · NLB · Traefik · VPC Link · ACM · Terraform

---

### 10. [eks-traefik](./eks-traefik)

A NestJS API and Next.js UI deployed on EKS with Traefik as the ingress controller, exposed through an internet-facing NLB with ACM TLS termination. No API Gateway — traffic goes directly NLB → Traefik → service.

**Stack:** EKS · NLB · Traefik · ACM · Terraform

---

### 11. [mock-web](./mock-web)

A reusable Next.js e-commerce UI (products and cart) used as the frontend component across multiple EKS-based projects. Includes a Dockerfile for containerised deployment and a deploy script targeting ECR.

**Stack:** Next.js · TypeScript · Tailwind CSS · Docker

---

### 12. [nlb-traefik-ingress-nestjs](./nlb-traefik-ingress-nestjs)

A Next.js frontend and NestJS API deployed on EKS, routed through Traefik ingress, and exposed via an internet-facing NLB with ACM TLS termination. Demonstrates internal service-to-service communication alongside external traffic routing.

**Stack:** EKS · NLB · Traefik · ACM · NestJS · Next.js · Terraform
