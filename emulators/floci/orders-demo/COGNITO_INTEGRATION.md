# Cognito Integration with Floci (LocalStack)

## Architecture

The authentication flow now works properly with LocalStack/Floci:

```
┌─────────────────┐
│  React Frontend │
│   (port 3000)   │
└────────┬────────┘
         │ HTTP API calls
         │
┌────────▼────────┐
│  Flask Backend  │        ┌──────────────┐
│   (port 5000)   │◄──────►│   Cognito    │
│                 │        │  (Floci)     │
└─────────────────┘        └──────────────┘
         ▲
         │ REST endpoints:
         │ • /auth/signin
         │ • /auth/signup
         │ • /auth/signout
```

## Setup Steps

### 1. Deploy Terraform Infrastructure

```bash
bash scripts/deploy-terraform.sh
```

This creates:
- Cognito User Pool (on Floci)
- Demo user: `demo@example.com` / `Demo@123456`
- Saves environment variables to `.env.terraform`

### 2. Start Flask Backend

Set up Cognito environment variables and start the Flask server:

```bash
# Source the terraform outputs (sets COGNITO_USER_POOL_ID, COGNITO_CLIENT_ID, etc.)
source .env.terraform

# Start Flask server (it will use the exported env vars)
python app.py
```

The backend is now ready at: `http://localhost:5000`

### 3. Build Frontend

```bash
bash scripts/build-frontend.sh
```

Creates `frontend/.env` with:
```env
REACT_APP_API_ENDPOINT=http://localhost:5000
REACT_APP_DEBUG=false
```

### 4. Start Frontend

```bash
bash scripts/start-frontend.sh
```

Frontend runs at: `http://localhost:3000`

## Authentication Flow

### Sign In

1. User enters email & password in frontend
2. Frontend calls `POST /auth/signin` on Flask backend
3. Backend calls LocalStack Cognito's `InitiateAuth`
4. Cognito validates credentials against the user pool
5. Backend returns `idToken`, `accessToken`, `refreshToken` to frontend
6. Frontend stores tokens in localStorage
7. Frontend uses `Authorization: Bearer {accessToken}` for API calls

### Sign Up

1. User enters email, password, name in frontend
2. Frontend calls `POST /auth/signup` on Flask backend
3. Backend creates user in LocalStack Cognito
4. Backend returns success response
5. User can then sign in

### Sign Out

1. Frontend calls `POST /auth/signout` with access token
2. Backend logs the sign out (token invalidation is stateless for demo)
3. Frontend clears tokens from localStorage

## Environment Variables

**Flask Backend** (must be set before running `python app.py`):
```bash
COGNITO_USER_POOL_ID=us-east-1_xxxxx
COGNITO_CLIENT_ID=xxxxxxxxxxxxx
AWS_ENDPOINT_URL=http://localhost:4566
AWS_ACCESS_KEY_ID=test
AWS_SECRET_ACCESS_KEY=test
AWS_DEFAULT_REGION=us-east-1
```

**React Frontend** (in `frontend/.env`):
```env
REACT_APP_API_ENDPOINT=http://localhost:5000
REACT_APP_DEBUG=false
```

## Testing with Demo User

```bash
# Demo credentials (created by Terraform)
Email: demo@example.com
Password: Demo@123456
```

Try signing in with these credentials - they now go through real Cognito validation on Floci, not a mock!

## Key Files

- **Flask Backend**: `app.py`
  - `/auth/signin` - Sign in endpoint
  - `/auth/signup` - Sign up endpoint
  - `/auth/signout` - Sign out endpoint
  - `@require_auth` - Decorator for protected routes

- **Frontend Service**: `frontend/src/services/CognitoAuthService.js`
  - Calls backend auth endpoints instead of AWS SDK
  - No longer mocked

- **Scripts**:
  - `scripts/deploy-terraform.sh` - Deploy Cognito + other services
  - `scripts/build-frontend.sh` - Build React app
  - `scripts/start-frontend.sh` - Start dev server

## Why This Architecture?

✅ **Security**: Frontend never handles AWS credentials
✅ **Local Development**: Works perfectly with Floci/LocalStack
✅ **No CORS Issues**: Backend can call LocalStack, frontend calls backend
✅ **Real Validation**: Uses actual Cognito (on Floci), not mocked
✅ **Stateless**: Tokens are JWT, backend doesn't store sessions
✅ **Scalable**: Easy to migrate to real AWS Cognito

## Troubleshooting

**"Cognito not configured"** error:
- Ensure you ran `source .env.terraform` before `python app.py`
- Check env vars: `echo $COGNITO_USER_POOL_ID`

**"Invalid credentials"** on sign in:
- Make sure you're using the demo user: `demo@example.com` / `Demo@123456`
- Or create a new user via the Sign Up form

**Frontend can't reach backend**:
- Check Flask is running on port 5000
- Verify `REACT_APP_API_ENDPOINT=http://localhost:5000` in `frontend/.env`

**Floci not running**:
- Run: `bash scripts/setup-floci.sh`
- Check status: `podman-compose ps`
