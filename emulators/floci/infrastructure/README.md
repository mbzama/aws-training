# Infrastructure as Code (IaC)

This directory is reserved for Infrastructure as Code definitions. The Event Ticket Booking Platform uses **AWS SAM (Serverless Application Model)** as its IaC framework.

## Current Approach: AWS SAM

**Location:** `backend/template.yaml`

AWS SAM is a framework that extends CloudFormation with simplified syntax for serverless applications. It provides:

- **Simpler syntax** for Lambda, API Gateway, DynamoDB, and other serverless services
- **Local development** with SAM CLI and LocalStack (Floci)
- **Quick deployment** to AWS with `sam deploy`
- **Built-in best practices** for IAM roles, permissions, and resource configuration
- **Intrinsic functions** for referencing resources and generating names

### Why SAM?

| Feature | AWS SAM | CDK | Terraform |
|---------|---------|-----|-----------|
| **Serverless-First** | ✓ Optimized | ✓ Good | Limited |
| **Learning Curve** | Easy (YAML) | Medium (Python/TS) | Medium (HCL) |
| **AWS Native** | ✓ Official | ✓ Official | ✓ Community |
| **Local Testing** | ✓ Excellent | Good | Limited |
| **Startup Speed** | ✓ Fast | Slower | Slower |
| **Type Safety** | No | ✓ Yes | ✓ Yes |
| **Maturity** | Stable | Stable | Mature |

For serverless, event-driven applications, SAM is the ideal choice.

## Template Structure

```
backend/
├── template.yaml          # Main SAM template
├── samconfig.toml         # SAM deployment config (auto-generated)
└── .aws-sam/              # Build artifacts (generated)
```

## SAM Template Overview

### Parameters
```yaml
Environment:
  Type: String
  Default: local
  Values: [local, dev, prod]
```

Allows environment-specific configuration (local Floci vs. AWS).

### Global Settings
```yaml
Globals:
  Function:
    Runtime: nodejs22.x
    Timeout: 30
    MemorySize: 256
```

Applied to all Lambda functions (can be overridden per-function).

### Resources

| Resource | Type | Purpose |
|----------|------|---------|
| **EventBookingUserPool** | `AWS::Cognito::UserPool` | User authentication |
| **EventBookingClient** | `AWS::Cognito::UserPoolClient` | Client app credentials |
| **EventBookingApi** | `AWS::Serverless::Api` | REST API endpoint |
| **BookingsTable** | `AWS::DynamoDB::Table` | Booking records |
| **EventsTable** | `AWS::DynamoDB::Table` | Event catalog |
| **BookingQueue** | `AWS::SQS::Queue` | Async task queue |
| **BookingQueueDLQ** | `AWS::SQS::Queue` | Failed message queue |
| **BookingTopic** | `AWS::SNS::Topic` | Event notifications |
| **TicketsBucket** | `AWS::S3::Bucket` | PDF ticket storage |
| **FrontendBucket** | `AWS::S3::Bucket` | React app hosting |
| **CloudFrontDistribution** | `AWS::CloudFront::Distribution` | CDN |
| **[4x Lambda Functions]** | `AWS::Serverless::Function` | Business logic |
| **[IAM Roles & Policies]** | Various | Least-privilege access |

### Outputs

```yaml
Outputs:
  ApiEndpoint:
    Value: !Sub 'https://${EventBookingApi}.execute-api.${AWS::Region}.amazonaws.com/prod'
  UserPoolId:
    Value: !Ref EventBookingUserPool
  # ... and more
```

Outputs are displayed after deployment and stored in CloudFormation for reference.

## Deployment Workflow

### Local (Floci)

```bash
cd backend

# Build
sam build

# Deploy to LocalStack
sam deploy \
  --use-container \
  --parameter-overrides Environment=local \
  --endpoint-url http://localhost:4566
```

### AWS Production

```bash
sam build
sam deploy \
  --s3-bucket my-artifacts-bucket \
  --stack-name event-booking-platform \
  --region us-east-1 \
  --capabilities CAPABILITY_NAMED_IAM
```

## SAM Commands Reference

```bash
# Validate template
sam validate

# Build (packages dependencies)
sam build

# Deploy (interactive)
sam deploy --guided

# Deploy (non-interactive)
sam deploy --stack-name my-stack

# Delete stack
sam delete --stack-name my-stack

# Local testing
sam local start-api
sam local invoke BookingFunction -e event.json

# Generate sample event
sam local generate-event apigateway aws-proxy > event.json
```

## Adding New Resources

To add a new Lambda function or DynamoDB table:

1. **Define resource in template.yaml:**
   ```yaml
   MyNewFunction:
     Type: AWS::Serverless::Function
     Properties:
       Handler: my-lambda/index.handler
       Runtime: nodejs22.x
       Environment:
         Variables:
           TABLE_NAME: !Ref MyTable
       Policies:
         - DynamoDBCrudPolicy:
             TableName: !Ref MyTable
   ```

2. **Rebuild and deploy:**
   ```bash
   sam build
   sam deploy
   ```

3. **Access outputs:**
   ```bash
   aws cloudformation describe-stacks --stack-name event-booking-platform --query 'Stacks[0].Outputs'
   ```

## Alternatives: CDK vs. Terraform

### AWS CDK (TypeScript/Python)

**Use case:** Large, complex infrastructure with programmatic logic

```python
# Example: CDK in Python
from aws_cdk import (
    aws_lambda,
    aws_dynamodb,
    core,
)

class EventBookingStack(core.Stack):
    def __init__(self, scope: core.Construct, id: str, **kwargs):
        super().__init__(scope, id, **kwargs)
        
        table = aws_dynamodb.Table(
            self, "Bookings",
            partition_key=aws_dynamodb.Attribute(name="userId", type=aws_dynamodb.AttributeType.STRING),
        )
```

**Pros:**
- Type-safe (TypeScript)
- Programmatic (loops, conditionals)
- Full AWS coverage

**Cons:**
- Steeper learning curve
- Slower cold starts
- More complex for serverless-only apps

### Terraform (HCL)

**Use case:** Multi-cloud, long-term infrastructure

```hcl
# Example: Terraform
resource "aws_dynamodb_table" "bookings" {
  name           = "Bookings"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "userId"
  range_key      = "bookingId"

  attribute {
    name = "userId"
    type = "S"
  }
}
```

**Pros:**
- Multi-cloud support
- Industry standard
- Large community

**Cons:**
- Non-AWS features can be verbosely configured
- State file management required
- Larger learning curve

## Migration Guide

### SAM to CDK

If your team prefers programmatic IaC:

```bash
# Install CDK CLI
npm install -g aws-cdk

# Create CDK app
cdk init app --language python

# Port SAM template to CDK
# (Roughly 1:1 mapping for most resources)
```

### SAM to Terraform

If you need multi-cloud support:

```bash
# Install Terraform
brew install terraform  # or download

# Create Terraform module from SAM
# (Define provider block and port resources)
```

## Best Practices

1. **Use Parameters** for environment-specific values
2. **Define IAM Policies** explicitly (least privilege)
3. **Use Globals** for consistent configuration
4. **Version Control** template.yaml (never commit credentials)
5. **Tag Resources** for cost tracking and organization
6. **Document** custom resources and parameters
7. **Test Locally** with SAM CLI before deploying to AWS

## Monitoring & Debugging

```bash
# View deployed stack
aws cloudformation describe-stacks --stack-name event-booking-platform

# View stack events
aws cloudformation describe-stack-events --stack-name event-booking-platform

# View stack resources
aws cloudformation list-stack-resources --stack-name event-booking-platform

# Delete stack (careful!)
aws cloudformation delete-stack --stack-name event-booking-platform
```

## References

- [AWS SAM Documentation](https://docs.aws.amazon.com/serverless-application-model/)
- [SAM Policy Templates](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/serverless-policy-templates.html)
- [CloudFormation Resource Reference](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-template-resource-type-ref.html)

---

**Current Status:** AWS SAM is the recommended and used approach for this project.
