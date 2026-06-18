# Terraform Infrastructure for Event Booking Platform with Floci

This directory contains Terraform configurations to deploy the Event Booking Platform infrastructure to Floci.

## Prerequisites

1. **Floci running** - Ensure Floci is running on `http://localhost:4566`:
   ```bash
   cd .. && docker-compose up -d
   ```

2. **Terraform installed** - Download from [terraform.io](https://www.terraform.io/downloads.html)

3. **AWS CLI configured** (optional, for manual verification):
   ```bash
   aws configure --profile floci
   ```

## Deployment

### 1. Initialize Terraform
```bash
cd terraform
terraform init
```

### 2. Plan the deployment
```bash
terraform plan -out=tfplan
```

### 3. Apply the configuration
```bash
terraform apply tfplan
```

This will:
- Create DynamoDB tables (Events, Bookings)
- Create SQS queue and DLQ for booking workflow
- Create S3 buckets for tickets and frontend
- Create Cognito User Pool
- Deploy Lambda functions
- Create API Gateway endpoints
- Set up event source mapping (SQS → Ticket Generator Lambda)
- Configure IAM roles and policies

### 4. Get the outputs
```bash
terraform output
```

Save the API endpoint for frontend configuration:
```bash
terraform output api_endpoint
```

## Manual Lambda Deployment

After updating Lambda code in `backend/`, redeploy:

```bash
# Force Lambda redeployment
terraform taint aws_lambda_function.booking
terraform taint aws_lambda_function.events
terraform taint aws_lambda_function.history
terraform taint aws_lambda_function.ticket_generator

terraform plan -out=tfplan
terraform apply tfplan
```

## Verifying Deployment

### Check DynamoDB Tables
```bash
aws dynamodb list-tables \
  --endpoint-url http://localhost:4566 \
  --region us-east-1
```

### Check Lambda Functions
```bash
aws lambda list-functions \
  --endpoint-url http://localhost:4566 \
  --region us-east-1
```

### Check API Gateway
```bash
aws apigateway get-rest-apis \
  --endpoint-url http://localhost:4566 \
  --region us-east-1
```

### Check SQS Queue
```bash
aws sqs list-queues \
  --endpoint-url http://localhost:4566 \
  --region us-east-1
```

## Cleanup

To destroy all resources:
```bash
terraform destroy
```

## Troubleshooting

### Terraform can't connect to Floci
Make sure Floci is running:
```bash
curl http://localhost:4566/_floci/health
```

### Lambda deployment fails
Ensure the backend code exists:
```bash
ls -la ../backend/{booking-lambda,events-lambda,history-lambda,ticket-generator-lambda}/index.js
```

### API Gateway returns 502
Check Lambda execution role has proper permissions and Lambda code has no syntax errors:
```bash
aws lambda get-function --function-name event-booking-book \
  --endpoint-url http://localhost:4566 \
  --region us-east-1
```
