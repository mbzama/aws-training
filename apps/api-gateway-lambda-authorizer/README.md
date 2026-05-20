# AWS API Gateway Lambda Authorizer

A production-ready **JWT Bearer token** Lambda Authorizer for API Gateway (HTTP API v2).

## How It Works

```
Client ──► API Gateway ──► Lambda Authorizer ──► IAM Policy (Allow/Deny)
                                                         │
                                                         ▼
                                               Backend Lambda (with user context)
```

1. Client sends `Authorization: Bearer <jwt>` with every request.
2. API Gateway invokes the **Lambda Authorizer** before routing the request.
3. The authorizer **verifies** the JWT (signature, expiry, issuer, audience, scopes).
4. It returns an IAM policy (`Allow` or `Deny`) plus a **context object** containing claims.
5. API Gateway caches the policy for `AuthorizerCacheTtl` seconds (default 5 min).
6. The backend Lambda receives decoded claims via `event.requestContext.authorizer.lambda`.

---

## Project Structure

```
.
├── lambda-authorizer/
│   ├── index.js          # Authorizer handler
│   ├── index.test.js     # Jest unit tests
│   └── package.json
├── infrastructure/
│   └── template.yaml     # SAM template (Lambda + API Gateway)
└── README.md
```

---

## Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| Node.js | ≥ 20 | https://nodejs.org |
| AWS CLI | ≥ 2 | `brew install awscli` |
| AWS SAM CLI | ≥ 1.100 | `brew install aws-sam-cli` |
| AWS account | – | Configured via `aws configure` |

---

## Quick Start

### 1. Install Dependencies

```bash
cd lambda-authorizer
npm install
```

### 2. Run Unit Tests

```bash
npm test
```

All 7 tests should pass, covering valid tokens, expired tokens, wrong signatures, scope checks, and ARN wildcarding.

### 3. Generate a Test JWT

```bash
# Install jwt-cli (optional, for quick token generation)
npm install -g jwt-cli

# Create a signed token (replace SECRET with your actual secret)
SECRET="my-super-secret-key-32-chars-min!"

node -e "
  const jwt = require('jsonwebtoken');
  const token = jwt.sign(
    { sub: 'user-123', email: 'alice@example.com', scope: 'read:pets', roles: ['user'] },
    '$SECRET',
    { algorithm: 'HS256', expiresIn: '1h', issuer: 'my-app' }
  );
  console.log(token);
"
```

---

## Deployment

### Step 1 — Configure AWS credentials

```bash
aws configure
# Enter: Access Key ID, Secret Access Key, region (e.g. us-east-1), output format (json)
```

### Step 2 — Create an S3 bucket for SAM artifacts (one-time)

```bash
BUCKET="sam-artifacts-$(aws sts get-caller-identity --query Account --output text)-us-east-1"
aws s3 mb s3://$BUCKET --region us-east-1
```

### Step 3 — Build the SAM application

```bash
cd infrastructure
sam build
```

### Step 4 — Deploy (guided first run)

```bash
sam deploy --guided
```

You will be prompted for:

| Parameter | Example Value | Notes |
|-----------|---------------|-------|
| `Stack Name` | `api-authorizer-demo` | CloudFormation stack name |
| `AWS Region` | `us-east-1` | Target region |
| `JwtSecret` | `my-super-secret-key-32-chars-min!` | Keep secret; not logged |
| `JwtAlgorithm` | `HS256` | Match your token signing algorithm |
| `JwtIssuer` | *(leave blank or set)* | Optional `iss` claim validation |
| `JwtAudience` | *(leave blank or set)* | Optional `aud` claim validation |
| `AllowedScopes` | `read:pets` | Comma-separated; leave blank to skip |
| `AuthorizerCacheTtl` | `300` | Seconds; set `0` during development |
| `StageName` | `prod` | API stage |

Settings are saved to `samconfig.toml` for subsequent runs.

### Step 5 — Subsequent deploys

```bash
sam deploy   # uses samconfig.toml
```

### Step 6 — Get the API endpoint

```bash
aws cloudformation describe-stacks \
  --stack-name api-authorizer-demo \
  --query 'Stacks[0].Outputs[?OutputKey==`ApiEndpoint`].OutputValue' \
  --output text
```

---

## Testing the Deployed API

After deploying, get the API endpoint from the CloudFormation stack outputs:

```bash
API_URL=$(aws cloudformation describe-stacks \
  --stack-name api-authorizer-demo \
  --query 'Stacks[0].Outputs[?OutputKey==`ApiEndpoint`].OutputValue' \
  --output text)

echo $API_URL
# https://<api-id>.execute-api.us-east-1.amazonaws.com/prod
```

---

### Step 1 — Generate a token using `generate-token.js`

```bash
cd lambda-authorizer

# Basic usage (sub required)
node generate-token.js user-123

# With email and scope
node generate-token.js user-123 alice@example.com "read:pets"

# With email, scope, and roles
node generate-token.js user-123 alice@example.com "read:pets write:pets" "user,admin"
```

The script prints the signed JWT and a ready-to-run `curl` command, e.g.:

```
Token (expires in 1h):
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

curl command:
curl -i -H "Authorization: Bearer eyJhbGci..." https://&lt;api-id&gt;.execute-api.us-east-1.amazonaws.com/prod/pets
```

> **Custom secret:** set `JWT_SECRET` env var to override the default:
> ```bash
> JWT_SECRET="my-own-secret" node generate-token.js user-123
> ```

---

### Step 2 — Send requests

#### Without a token (expect 401)

```bash
curl -i $API_URL/pets
# HTTP/2 401
```

#### With a valid JWT (expect 200)

```bash
TOKEN=$(node generate-token.js user-123 alice@example.com "read:pets" | grep "^ey")

curl -i -H "Authorization: Bearer $TOKEN" $API_URL/pets
# HTTP/2 200
# {"message":"Hello from the protected endpoint!","userId":"user-123","email":"alice@example.com",...}
```

#### With an expired / tampered token (expect 401 or 403)

```bash
curl -i -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.invalid.signature" $API_URL/pets
# HTTP/2 401
```

---

### Unit Tests

Run all unit tests locally (no AWS required):

```bash
cd lambda-authorizer
npm test
```

All 7 tests cover valid tokens, expired tokens, wrong signatures, scope checks, and ARN wildcarding.

---

## Environment Variables Reference

| Variable | Required | Description |
|----------|----------|-------------|
| `JWT_SECRET` | Yes | HMAC secret (HS*) or RSA/EC public key PEM (RS*/ES*) |
| `JWT_ALGORITHM` | No | Default: `HS256` |
| `JWT_ISSUER` | No | Validates the `iss` claim |
| `JWT_AUDIENCE` | No | Validates the `aud` claim |
| `ALLOWED_SCOPES` | No | Comma-separated required scopes |

---

## Using RS256 (Asymmetric Keys)

For production systems, use **RS256** so the secret never leaves your signing service.

```bash
# Generate a key pair
openssl genrsa -out private.pem 2048
openssl rsa -in private.pem -pubout -out public.pem

# Sign tokens with private.pem (auth server)
# Set JWT_SECRET = contents of public.pem in the Lambda env var
# Set JWT_ALGORITHM = RS256
```

Store the public key in **AWS Secrets Manager** and retrieve it at Lambda cold start:

```js
// Example: load public key from Secrets Manager
const { SecretsManagerClient, GetSecretValueCommand } = require('@aws-sdk/client-secrets-manager');
const client = new SecretsManagerClient({});

let cachedKey;
async function getPublicKey() {
  if (!cachedKey) {
    const res = await client.send(new GetSecretValueCommand({ SecretId: process.env.PUBLIC_KEY_SECRET_ARN }));
    cachedKey = res.SecretString;
  }
  return cachedKey;
}
```

---

## Authorizer Policy Caching

- Cache is keyed on the **incoming token** (not per-user).
- Default TTL: **300 seconds** (5 minutes).
- Set `AuthorizerCacheTtl: 0` to **disable** during development so every request calls the authorizer.
- Re-enable caching in production to reduce latency and Lambda invocations.

---

## Accessing Authorizer Context in the Backend

The `context` object returned by the authorizer is available in the backend Lambda via:

```js
// HTTP API (v2)
const auth = event.requestContext.authorizer.lambda;
console.log(auth.userId, auth.email, auth.roles, auth.scopes);

// REST API (v1)
const auth = event.requestContext.authorizer;
console.log(auth.userId, auth.email);
```

> **Note:** All context values must be **strings**. Arrays/objects are JSON-stringified.

---

## Cleanup

```bash
sam delete --stack-name api-authorizer-demo
```

---

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| `401 Unauthorized` on every request | Missing or malformed `Authorization` header | Ensure header format is `Bearer <token>` |
| `401` with a valid-looking token | `JWT_SECRET` mismatch or wrong algorithm | Verify env vars match signing config |
| `403 Forbidden` | Token valid but scope/policy denied | Check `ALLOWED_SCOPES` setting |
| `500 Internal Server Error` | Unhandled exception in authorizer | Check CloudWatch logs: `/aws/lambda/<stack>-authorizer` |
| Stale policy after token change | Authorizer cache TTL not expired | Set `AuthorizerCacheTtl: 0` in dev |
| Cold start latency | Lambda not warmed | Enable Provisioned Concurrency or Lambda SnapStart |

### View authorizer logs

```bash
sam logs --name AuthorizerFunction --stack-name api-authorizer-demo --tail
```
