# Next.js + AWS Secrets Manager

A Next.js app that securely loads secrets from AWS Secrets Manager at startup — either via a Docker init container (local/compose) or a Kubernetes init container (EKS).

---

## How it works

1. An **init container** (`amazon/aws-cli`) calls `secretsmanager get-secret-value` and writes the JSON payload to a shared volume at `/mnt/aws-secrets/app_web.json`.
2. The **Next.js app** starts only after the init container completes successfully.
3. The API route (`/api/secret`) reads keys directly from the mounted file. If the file is absent it falls back to calling AWS Secrets Manager directly via the SDK.

---

## Prerequisites

- Docker + Docker Compose
- AWS credentials with `secretsmanager:GetSecretValue` permission
- The secret `app_web` must exist in AWS Secrets Manager (see below)

---

## 1. Create the secret in AWS

```bash
aws secretsmanager create-secret \
  --region us-east-1 \
  --name app_web \
  --secret-string '{"DB_HOST":"localhost","DB_PORT":"5432","API_KEY":"your-api-key"}'
```

To update an existing secret:

```bash
aws secretsmanager put-secret-value \
  --secret-id app_web \
  --secret-string '{"DB_HOST":"prod-db","DB_PORT":"5432","API_KEY":"new-key"}'
```

---

## 2. Run with Docker Compose

Export your AWS credentials, then start the stack:

```bash
export AWS_ACCESS_KEY_ID=your-access-key-id
export AWS_SECRET_ACCESS_KEY=your-secret-access-key
export AWS_SESSION_TOKEN=your-session-token   # only if using temporary credentials

docker-compose up
```

The app will be available at `http://localhost:3000`.

**Override defaults with env vars:**

| Variable | Default | Description |
|---|---|---|
| `AWS_REGION` | `us-east-1` | AWS region |
| `SECRET_NAME` | `app_web` | Secrets Manager secret name |

---

## 3. Test the API

The `/api/secret` endpoint accepts a `name` query param — the key to look up inside the secret JSON.

```bash
curl "http://localhost:3000/api/secret?name=DB_HOST"
curl "http://localhost:3000/api/secret?name=DB_PORT"
curl "http://localhost:3000/api/secret?name=API_KEY"
```

Pretty-printed:

```bash
curl -s "http://localhost:3000/api/secret?name=DB_HOST" | jq .
```

Test all keys at once:

```bash
for key in DB_HOST DB_PORT API_KEY; do
  echo "--- $key ---"
  curl -s "http://localhost:3000/api/secret?name=$key" | jq .
done
```

Expected response:

```json
{
  "name": "DB_HOST",
  "value": "localhost"
}
```

---

## 4. Deploy to Kubernetes (Helm)

### Prerequisites

- `kubectl` configured for your cluster
- `helm` v3+
- Docker image pushed to a registry your cluster can pull from

### Option A — IRSA (recommended for EKS)

Attach an IAM role to the pod's service account so no credentials are needed in the manifest:

```bash
export RELEASE_NAME=aws-secrets-app
export NAMESPACE=default
export IMAGE_REPO=123456789.dkr.ecr.us-east-1.amazonaws.com/nextjs-web
export IMAGE_TAG=latest
export AWS_REGION=us-east-1
export SECRET_NAME=app_web
export IRSA_ROLE_ARN=arn:aws:iam::123456789:role/your-irsa-role
export REGISTRY=123456789.dkr.ecr.us-east-1.amazonaws.com

./deploy.sh
```

### Option B — Explicit credentials (dev/local clusters only)

```bash
export AWS_ACCESS_KEY_ID=your-access-key-id
export AWS_SECRET_ACCESS_KEY=your-secret-access-key
export IMAGE_REPO=nextjs-web
export IMAGE_TAG=latest

./deploy.sh
```

> The script builds and pushes the image, creates the namespace if needed, and runs `helm upgrade --install`.

### Manual Helm install

```bash
helm upgrade --install aws-secrets-app ./helm/aws-secrets-app \
  --namespace default \
  --set image.repository=nextjs-web \
  --set image.tag=latest \
  --set aws.region=us-east-1 \
  --set aws.secretName=app_web \
  --set aws.irsaRoleArn=arn:aws:iam::123456789:role/your-irsa-role
```

### Helm values reference

| Value | Default | Description |
|---|---|---|
| `image.repository` | `nextjs-web` | Container image repository |
| `image.tag` | `latest` | Image tag |
| `aws.region` | `us-east-1` | AWS region |
| `aws.secretName` | `app_web` | Secret name in Secrets Manager |
| `aws.irsaRoleArn` | `""` | IAM role ARN for IRSA (EKS) |
| `awsCredentials.accessKeyId` | `""` | Explicit key ID (dev only) |
| `awsCredentials.secretAccessKey` | `""` | Explicit secret key (dev only) |
| `replicaCount` | `1` | Number of pod replicas |
| `service.type` | `ClusterIP` | Kubernetes service type |
| `ingress.enabled` | `false` | Enable ingress |
| `ingress.host` | `app.example.com` | Ingress hostname |

---

## Project structure

```
.
├── app/
│   ├── api/secret/route.ts   # Secret lookup API endpoint
│   ├── page.tsx
│   └── layout.tsx
├── helm/
│   └── aws-secrets-app/
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
│           ├── deployment.yaml   # Init container + Next.js app
│           ├── service.yaml
│           ├── serviceaccount.yaml
│           ├── ingress.yaml
│           └── secret.yaml       # AWS credentials (dev only)
├── Dockerfile
├── docker-compose.yaml
└── deploy.sh                 # Build, push, and helm deploy script
```
