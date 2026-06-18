# Troubleshooting Guide

## Common Issues and Solutions

### Floci / LocalStack Issues

#### 1. Floci container won't start

**Symptoms:**
```
Error: Cannot start container
```

**Solutions:**

*macOS / Linux:*
```bash
# Check if port 4566 is in use
lsof -i :4566

# Kill existing process using port
kill -9 <PID>

# Restart Floci
podman stop floci
podman rm floci
podman run -d --name floci -p 4566:4566 localstack/localstack:latest
```

*Windows (PowerShell):*
```powershell
# Check if port 4566 is in use
netstat -ano | findstr :4566

# Kill existing process using port (if PID is 1234)
taskkill /PID 1234 /F

# Restart Floci
docker stop floci
docker rm floci
docker run -d --name floci -p 4566:4566 localstack/localstack:latest
```

#### 2. Floci services not available

**Symptoms:**
```
curl: (7) Failed to connect to localhost port 4566
```

**Solutions:**
```bash
# Check Floci health
curl http://localhost:4566/_localstack/health

# Check if container is running
podman ps | grep floci

# View logs
podman logs floci

# Restart with additional services
podman run -d --name floci -p 4566:4566 \
  -e SERVICES=dynamodb,lambda,sqs,sns,s3,apigateway,cognito-idp \
  localstack/localstack:latest
```

#### 3. DynamoDB tables not persisting

**Symptoms:**
- Tables disappear after container restart

**Solutions:**
- Use Docker volume for persistence:
```bash
podman run -d --name floci -p 4566:4566 \
  -v localstack_data:/tmp/localstack \
  localstack/localstack:latest
```

---

### AWS CLI Issues

#### 1. AWS CLI authentication fails

**Symptoms:**
```
Error: Unable to locate credentials
```

**Solutions:**
```bash
# Configure credentials
aws configure

# Or set environment variables
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1

# Test connection
aws sts get-caller-identity --endpoint-url http://localhost:4566
```

#### 2. Wrong endpoint configuration

**Symptoms:**
```
NoCredentialsError: Unable to locate credentials
```

**Solutions:**
```bash
# Set endpoint for each command
aws s3 ls --endpoint-url http://localhost:4566

# Or create AWS profile with endpoint
aws configure set profile.local.endpoint_url http://localhost:4566

# Then use profile
aws s3 ls --profile local
```

---

### SAM Deployment Issues

#### 1. SAM build fails

**Symptoms:**
```
ERROR: Runtime nodejs22.x is not supported
```

**Solutions:**
```bash
# Update SAM CLI
pip install --upgrade aws-sam-cli

# Check supported runtimes
sam --version

# Update template.yaml to supported runtime
# Change: Runtime: nodejs22.x
# To: Runtime: nodejs18.x (if 22 not available)
```

#### 2. Stack creation fails

**Symptoms:**
```
The following resource(s) failed to create: CognitoUserPool
```

**Solutions:**
```bash
# Check CloudFormation errors
aws cloudformation describe-stack-events \
  --stack-name event-booking-platform \
  --endpoint-url http://localhost:4566

# Check stack status
aws cloudformation describe-stacks \
  --stack-name event-booking-platform \
  --endpoint-url http://localhost:4566

# Delete and retry
aws cloudformation delete-stack \
  --stack-name event-booking-platform \
  --endpoint-url http://localhost:4566

sam deploy --guided
```

#### 3. Lambda function deployment fails

**Symptoms:**
```
ERROR: Could not upload Lambda package
```

**Solutions:**
```bash
# Check Lambda service
aws lambda list-functions --endpoint-url http://localhost:4566

# Verify SAM build
sam build

# Check for large package
du -sh .aws-sam/build/

# Reduce package size by removing node_modules and rebuilding
rm -rf backend/*/node_modules
npm install --production
sam build
```

---

### Lambda Function Issues

#### 1. Lambda timeout

**Symptoms:**
```
Task timed out after 30.00 seconds
```

**Solutions:**
```bash
# Increase timeout in template.yaml
Globals:
  Function:
    Timeout: 60  # Increase from 30

# Redeploy
sam deploy

# Check execution duration
aws logs tail /aws/lambda/event-booking-book --follow
```

#### 2. Lambda out of memory

**Symptoms:**
```
Process exited before completing request (signal: SIGKILL)
```

**Solutions:**
```bash
# Increase memory in template.yaml
Globals:
  Function:
    MemorySize: 512  # Increase from 256

# For ticket generator (intensive)
TicketGeneratorFunction:
  MemorySize: 1024

# Redeploy
sam deploy
```

#### 3. Lambda cold start issues

**Symptoms:**
- First invocation takes 5+ seconds

**Solutions:**
```bash
# Reduce package size
npm install --production

# Use Lambda layers for dependencies
aws lambda publish-layer-version \
  --layer-name node-dependencies \
  --zip-file fileb://layers.zip

# Enable provisioned concurrency (production)
# In template.yaml:
# ProvisionedConcurrentExecutions: 5
```

#### 4. Lambda permissions error

**Symptoms:**
```
User: arn:aws:iam::123456789012:role/lambda-role is not authorized
```

**Solutions:**
```bash
# Check IAM policy for Lambda
aws iam get-role-policy \
  --role-name event-booking-lambda-role \
  --policy-name lambda-policy

# Verify DynamoDB permission
aws dynamodb describe-table \
  --table-name Bookings

# Check policy attachment
aws iam list-attached-role-policies \
  --role-name event-booking-lambda-role
```

---

### DynamoDB Issues

#### 1. Table not found

**Symptoms:**
```
ResourceNotFoundException: Requested resource not found
```

**Solutions:**
```bash
# List tables
aws dynamodb list-tables --endpoint-url http://localhost:4566

# Create table manually if missing
aws dynamodb create-table \
  --table-name Bookings \
  --attribute-definitions AttributeName=userId,AttributeType=S \
  --key-schema AttributeName=userId,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --endpoint-url http://localhost:4566

# Redeploy SAM stack
sam deploy
```

#### 2. Insufficient throughput (provisioned mode)

**Symptoms:**
```
ProvisionedThroughputExceededException
```

**Solutions:**
```bash
# Use PAY_PER_REQUEST instead
# In template.yaml:
BookingsTable:
  BillingMode: PAY_PER_REQUEST  # Auto-scaling

# Or increase provisioned capacity
aws dynamodb update-table \
  --table-name Bookings \
  --provisioned-throughput ReadCapacityUnits=10,WriteCapacityUnits=10
```

#### 3. Query returns no results

**Symptoms:**
- Bookings not found for user

**Solutions:**
```bash
# Scan entire table to check data
aws dynamodb scan --table-name Bookings

# Check specific user
aws dynamodb query \
  --table-name Bookings \
  --key-condition-expression "userId = :uid" \
  --expression-attribute-values '{":uid":{"S":"user123"}}'

# Verify data inserted correctly
aws dynamodb get-item \
  --table-name Bookings \
  --key '{
    "userId": {"S": "user123"},
    "bookingId": {"S": "BOOK-123"}
  }'
```

---

### SQS Issues

#### 1. Messages not being processed

**Symptoms:**
- Messages stay in queue
- Lambda not triggered

**Solutions:**
```bash
# Check queue attributes
aws sqs get-queue-attributes \
  --queue-url http://localhost:4566/000000000000/BookingQueue \
  --attribute-names All

# Check for messages
aws sqs receive-message \
  --queue-url http://localhost:4566/000000000000/BookingQueue

# Check Lambda trigger configuration
aws lambda list-event-source-mappings \
  --function-name event-booking-ticket-generator

# Check DLQ for failed messages
aws sqs receive-message \
  --queue-url http://localhost:4566/000000000000/BookingQueueDLQ
```

#### 2. Message visibility timeout too short

**Symptoms:**
```
Message processed twice - second attempt while processing first
```

**Solutions:**
```bash
# Increase visibility timeout
aws sqs set-queue-attributes \
  --queue-url http://localhost:4566/000000000000/BookingQueue \
  --attributes VisibilityTimeout=300

# Check current setting
aws sqs get-queue-attributes \
  --queue-url http://localhost:4566/000000000000/BookingQueue \
  --attribute-names VisibilityTimeout
```

---

### SNS Issues

#### 1. Notifications not being sent

**Symptoms:**
- SNS topic receives message but no email received

**Solutions:**
```bash
# Check topic exists
aws sns list-topics --endpoint-url http://localhost:4566

# List subscriptions
aws sns list-subscriptions --endpoint-url http://localhost:4566

# Check subscription endpoint
aws sns get-subscription-attributes \
  --subscription-arn <subscription-arn>

# Publish test message
aws sns publish \
  --topic-arn <topic-arn> \
  --subject "Test" \
  --message "Test message"
```

#### 2. Email subscription pending

**Symptoms:**
```
Subscription pending confirmation
```

**Solutions:**
- Confirm subscription (check email)
- For local testing, use SQS subscription instead:
```bash
aws sns subscribe \
  --topic-arn <topic-arn> \
  --protocol sqs \
  --notification-endpoint <queue-arn>
```

---

### API Gateway Issues

#### 1. CORS errors in frontend

**Symptoms:**
```
Access to XMLHttpRequest blocked by CORS policy
```

**Solutions:**
- Add CORS configuration to template.yaml:
```yaml
EventBookingApi:
  Type: AWS::Serverless::Api
  Properties:
    Cors:
      AllowHeaders: "'Content-Type,Authorization'"
      AllowMethods: "'GET,POST,OPTIONS'"
      AllowOrigin: "'*'"
```

- Or add CORS headers in Lambda response:
```javascript
return {
  statusCode: 200,
  headers: {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
  },
  body: JSON.stringify(data),
};
```

#### 2. Unauthorized errors (401)

**Symptoms:**
```
Unauthorized
```

**Solutions:**
```bash
# Check Cognito authorizer configuration
aws apigateway get-authorizer \
  --rest-api-id <api-id> \
  --authorizer-id <authorizer-id>

# Verify JWT token
# Decode token to check claims
jwt_decode <token>

# Refresh token if expired
aws cognito-idp admin-initiate-auth \
  --user-pool-id <pool-id> \
  --client-id <client-id> \
  --auth-flow ADMIN_NO_SRP_AUTH \
  --auth-parameters USERNAME=user@example.com,PASSWORD=password
```

#### 3. 404 Not Found errors

**Symptoms:**
```
Cannot POST /api/book
```

**Solutions:**
```bash
# Check API deployment
aws apigateway get-deployments --rest-api-id <api-id>

# Verify resource paths
aws apigateway get-resources --rest-api-id <api-id>

# Create missing resource
aws apigateway create-resource \
  --rest-api-id <api-id> \
  --parent-id <parent-id> \
  --path-part book
```

---

### Cognito Issues

#### 1. User pool not accessible

**Symptoms:**
```
NotAuthorizedException: Client does not have permission
```

**Solutions:**
```bash
# List user pools
aws cognito-idp list-user-pools --max-results 10

# Get user pool details
aws cognito-idp describe-user-pool --user-pool-id <pool-id>

# Check client configuration
aws cognito-idp describe-user-pool-client \
  --user-pool-id <pool-id> \
  --client-id <client-id>
```

#### 2. JWT token validation fails

**Symptoms:**
```
Invalid JWT token
```

**Solutions:**
```bash
# Check token expiration
# Decode and check 'exp' field in JWT

# Refresh token
aws cognito-idp initiate-auth \
  --auth-flow REFRESH_TOKEN_AUTH \
  --client-id <client-id> \
  --auth-parameters REFRESH_TOKEN=<refresh-token>
```

---

### Frontend Issues

#### 1. Blank page / 404 from S3

**Symptoms:**
- Frontend loads blank page

**Solutions:**
```bash
# Check S3 bucket website configuration
aws s3 website s3://<bucket-name>

# Check uploaded files
aws s3 ls s3://<bucket-name>/

# Check index.html exists
aws s3 ls s3://<bucket-name>/index.html

# Re-upload frontend
cd frontend
npm run build
aws s3 sync build/ s3://<bucket-name>/ --acl public-read
```

#### 2. API endpoint connection fails

**Symptoms:**
```
Failed to fetch http://localhost:3000/api/events
```

**Solutions:**
```bash
# Check .env file
cat frontend/.env

# Verify API endpoint is correct
echo $REACT_APP_API_ENDPOINT

# Test API directly
curl $REACT_APP_API_ENDPOINT/events

# Check CORS headers
curl -i -X OPTIONS $REACT_APP_API_ENDPOINT/events \
  -H "Origin: http://localhost:3000"
```

#### 3. Cognito integration fails

**Symptoms:**
```
Cognito initialization failed
```

**Solutions:**
```bash
# Check environment variables
cat frontend/.env

# Verify Cognito IDs are correct
aws cognito-idp list-user-pools --max-results 10

# Check Cognito config in code
grep -r "UserPoolId" frontend/src/

# Verify callback URLs in Cognito
aws cognito-idp describe-user-pool-client \
  --user-pool-id <pool-id> \
  --client-id <client-id> | jq '.UserPoolClient.CallbackURLs'
```

---

### Performance Issues

#### 1. Slow API responses

**Symptoms:**
- API takes >1 second to respond

**Solutions:**
```bash
# Check Lambda duration
aws logs get-log-events \
  --log-group-name /aws/lambda/event-booking-book \
  --log-stream-name <latest> | grep "Duration"

# Check for cold starts
grep "REPORT" /var/log/lambda/*.log | grep "Init Duration"

# Optimize code:
# - Reduce library imports
# - Use connection pooling
# - Enable Lambda layers

# Increase memory (correlates with CPU)
# In template.yaml: MemorySize: 512
```

#### 2. High DynamoDB latency

**Symptoms:**
- Database queries take >100ms

**Solutions:**
```bash
# Check table capacity
aws dynamodb describe-table --table-name Bookings

# Enable CloudWatch metrics
# Check consumed capacity

# Consider caching:
# - Use ElastiCache for frequently accessed data
# - Implement Lambda function result caching

# Optimize queries:
# - Use partition key efficiently
# - Avoid full scans
# - Use GSI for alternate queries
```

---

### Logging and Debugging

#### 1. Enable debug logging

```bash
# Set LOG_LEVEL environment variable
export LOG_LEVEL=DEBUG

# Redeploy Lambda
sam deploy

# View logs
aws logs tail /aws/lambda/event-booking-book --follow
```

#### 2. View CloudWatch logs

```bash
# Get latest log events
aws logs tail /aws/lambda/event-booking-book --follow

# Search for errors
aws logs filter-log-events \
  --log-group-name /aws/lambda/event-booking-book \
  --filter-pattern "ERROR"

# Get metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Errors \
  --dimensions Name=FunctionName,Value=event-booking-book
```

#### 3. Enable X-Ray tracing

```bash
# View X-Ray service map
aws xray get-service-graph --start-time 2026-06-09T00:00:00Z

# Get traces
aws xray batch-get-traces --trace-ids <trace-id>
```

---

## Getting Help

**Resources:**
- AWS Documentation: https://docs.aws.amazon.com/
- LocalStack Issues: https://github.com/localstack/localstack/issues
- Project Repository Issues: [GitHub]

**Debug Information to Collect:**
- CloudFormation events
- Lambda logs
- API Gateway logs
- X-Ray traces
- AWS CLI version
- SAM CLI version
- Node.js version

**Reporting Issues:**
1. Provide steps to reproduce
2. Include error messages and logs
3. Attach sanitized configuration files
4. Include environment details (OS, versions)
