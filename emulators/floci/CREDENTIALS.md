# Demo Credentials (Development Only)

⚠️ **FOR DEVELOPMENT USE ONLY**

Do not commit this file to public repositories.

## Demo User

| Field | Value |
|-------|-------|
| **Email** | demo@example.com |
| **Password** | Demo@123456 |

## How to Use

1. Open http://localhost:3000
2. Click "Sign In"
3. Enter the credentials above
4. Click "Sign In"

## Create New User

You can also create a new user by:
1. Click "Sign Up" on the login page
2. Enter your email and password
3. Create account
4. Sign in with your credentials

## Notes

- Credentials are created in `scripts/deploy-manual.sh`
- Cognito is running on Floci (LocalStack)
- User pool: `EventBookingUserPool`
- Client ID: Check `.env` file

