# Simple Setup Guide - Event Booking Platform

## Prerequisites
- Podman (Windows or WSL)
- Terraform
- Python 3.8+
- Node.js 16+

## Step-by-Step Setup

### 1. Start Floci (LocalStack)
```bash
podman-compose up -d
```

**Expected output:**
- Container `floci-event-booking` starts on port 4566
- Wait 10-15 seconds for the container to fully initialize

**Troubleshooting:**
- If container fails to start: `podman-compose logs floci`
- If connection refused: Wait longer (up to 30 seconds)

---

### 2. Deploy Infrastructure with Terraform

```bash
cd terraform
terraform init
terraform apply -auto-approve
cd ..
```

**Expected output:**
- Terraform creates Cognito User Pool, DynamoDB tables, S3 bucket, Lambda, SQS, SNS
- Outputs include `user_pool_id` and `user_pool_client_id`
- Takes 1-2 minutes

**Troubleshooting:**
- "Error: endpoint URL invalid": Floci not running (go back to step 1)
- "Error: NoCredentialProviders": This is expected for local Floci setup, ignore
- If slow: Check Floci health with: `curl http://localhost:4566/_localstack/health`

---

### 3. Sync Environment Variables

After Terraform completes, sync the outputs to .env files:

```bash
bash sync-env.sh
```

**What this does:**
- Reads Cognito credentials from Terraform outputs
- Creates `.env` file (for Flask backend with `COGNITO_USER_POOL_ID` and `COGNITO_CLIENT_ID`)
- Creates `frontend/.env` file (for React frontend with `REACT_APP_COGNITO_*` vars)

**Verify:**
```bash
cat .env
cat frontend/.env
```

---

### 4. Start Backend (Python Flask)

```bash
pip install -r requirements.txt
python app.py
```

**Expected output:**
```
[OK] Flask API running on http://localhost:5000
[OK] Auth: POST http://localhost:5000/auth/signin
[OK] Auth: POST http://localhost:5000/auth/signup
...
```

**Troubleshooting:**
- "Module not found": Run `pip install -r requirements.txt`
- "Address already in use": Port 5000 in use, kill it or change port
- "Connection refused": Floci not running or not healthy (check step 1)

**Note:** Keep this terminal running. Open a new terminal for step 5.

---

### 5. Start Frontend (React)

In a **new terminal**:

```bash
cd frontend
npm install
npm start
```

**Expected output:**
- React dev server starts on `http://localhost:3000`
- Browser opens automatically
- You can login with: `demo@example.com` / `Demo@123456`

---

## Environment Variables Explanation

### Backend (.env file - auto-created by sync-env.sh)
```env
COGNITO_USER_POOL_ID=us-east-1_xxxxxx      # From Terraform output
COGNITO_CLIENT_ID=xxxxxx                    # From Terraform output
```

The Flask app reads these for authentication endpoints:
- `POST /auth/signin` - Uses `COGNITO_USER_POOL_ID` and `COGNITO_CLIENT_ID`
- `POST /auth/signup` - Uses `COGNITO_USER_POOL_ID`

### Frontend (.env file - auto-created by sync-env.sh)
```env
REACT_APP_COGNITO_USER_POOL_ID=us-east-1_xxxxxx      # Cognito User Pool ID
REACT_APP_COGNITO_CLIENT_ID=xxxxxx                    # Cognito Client ID
REACT_APP_API_ENDPOINT=http://localhost:5000         # Backend URL
REACT_APP_COGNITO_REGION=us-east-1                   # AWS Region
REACT_APP_DEBUG=false                                 # Debug mode
```

The React app uses these to configure AWS Amplify for authentication.

---

## Full Workflow (5 Commands)

```bash
# Terminal 1
podman-compose up -d
sleep 15

# Terminal 1
cd terraform && terraform init && terraform apply -auto-approve && cd ..

# Terminal 1
bash sync-env.sh

# Terminal 1 (keep running)
pip install -r requirements.txt
python app.py

# Terminal 2
cd frontend && npm install && npm start
```

---

## Accessing the Application

**Frontend:** http://localhost:3000
- Email: `demo@example.com`
- Password: `Demo@123456`

**Backend API:** http://localhost:5000
- Health: `GET /health`
- Events: `GET /events`
- Book: `POST /book`
- History: `GET /history`
- Auth: `POST /auth/signin`, `POST /auth/signup`

**Floci Admin:** http://localhost:4566

---

## Cleanup

```bash
# Stop frontend (Ctrl+C in frontend terminal)
# Stop backend (Ctrl+C in backend terminal)

# Stop containers
podman-compose down

# Destroy Terraform
cd terraform
terraform destroy -auto-approve
cd ..
```

---

## Common Issues

| Issue | Solution |
|-------|----------|
| "Cannot connect to Floci" | Wait 15+ seconds after `podman-compose up -d` |
| "Port 5000/3000 already in use" | Kill the process or change port in app.py / package.json |
| "Module not found" | Run `pip install -r requirements.txt` |
| "Cognito not configured" | Run `bash sync-env.sh` after Terraform |
| "Invalid credentials" | Make sure demo user exists (Terraform should create it) |
| Terraform hangs | Check Floci health: `curl http://localhost:4566/_localstack/health` |

---

## Architecture

```
┌─────────────────────────────────────────────┐
│     Browser (http://localhost:3000)         │
│     React Frontend + AWS Amplify            │
└──────────────────┬──────────────────────────┘
                   │
                   ↓ (API calls + auth)
┌─────────────────────────────────────────────┐
│    Flask Backend (http://localhost:5000)    │
│    - DynamoDB: Events, Bookings            │
│    - S3: Tickets                           │
│    - Cognito: User authentication          │
│    - SQS/SNS: Async messaging              │
└──────────────────┬──────────────────────────┘
                   │
                   ↓ (AWS SDK boto3)
┌─────────────────────────────────────────────┐
│  Floci/LocalStack (http://localhost:4566)   │
│  AWS Services Emulator                      │
└─────────────────────────────────────────────┘
```
