#!/bin/bash
echo "Setting up Healthcare Demo on MiniStack..."

export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
export AWS_ENDPOINT_URL=http://localhost:4566

echo "Waiting for MiniStack..."
until curl -s http://localhost:4566/health | grep -q '"edition"'; do
  sleep 2
done
echo "✓ MiniStack is ready"

aws dynamodb create-table \
  --table-name patient-appointments \
  --attribute-definitions AttributeName=appointmentId,AttributeType=S \
  --key-schema AttributeName=appointmentId,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --endpoint-url http://localhost:4566 > /dev/null 2>&1
echo "✓ DynamoDB - patient-appointments"

aws s3 mb s3://healthcare-records --endpoint-url http://localhost:4566 > /dev/null 2>&1
echo "✓ S3 - healthcare-records"

TOPIC_ARN=$(aws sns create-topic --name patient-notifications \
  --endpoint-url http://localhost:4566 --query TopicArn --output text)
echo "✓ SNS - patient-notifications"

aws sqs create-queue --queue-name appointment-queue \
  --endpoint-url http://localhost:4566 > /dev/null 2>&1
echo "✓ SQS - appointment-queue"

aws sns subscribe --topic-arn $TOPIC_ARN --protocol sqs \
  --notification-endpoint arn:aws:sqs:us-east-1:000000000000:appointment-queue \
  --endpoint-url http://localhost:4566 > /dev/null 2>&1
echo "✓ SNS→SQS subscription"

aws kinesis create-stream --stream-name patient-events --shard-count 1 \
  --endpoint-url http://localhost:4566 > /dev/null 2>&1
echo "✓ Kinesis - patient-events"

aws lambda create-function \
  --function-name producer \
  --runtime nodejs18.x \
  --handler producer.handler \
  --zip-file fileb:///root/healthcare-demo/producer.zip \
  --role arn:aws:iam::000000000000:role/lambda-role \
  --endpoint-url http://localhost:4566 > /dev/null 2>&1
echo "✓ Lambda - producer"
sleep 3

API_ID=$(aws apigateway create-rest-api --name healthcare-api \
  --endpoint-url http://localhost:4566 --query id --output text)
ROOT_ID=$(aws apigateway get-resources --rest-api-id $API_ID \
  --endpoint-url http://localhost:4566 --query "items[0].id" --output text)
RESOURCE_ID=$(aws apigateway create-resource --rest-api-id $API_ID \
  --parent-id $ROOT_ID --path-part appointments \
  --endpoint-url http://localhost:4566 --query id --output text)
aws apigateway put-method --rest-api-id $API_ID --resource-id $RESOURCE_ID \
  --http-method POST --authorization-type NONE \
  --endpoint-url http://localhost:4566 > /dev/null 2>&1
aws apigateway put-integration --rest-api-id $API_ID --resource-id $RESOURCE_ID \
  --http-method POST --type AWS_PROXY --integration-http-method POST \
  --uri "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:000000000000:function:producer/invocations" \
  --endpoint-url http://localhost:4566 > /dev/null 2>&1
aws apigateway create-deployment --rest-api-id $API_ID --stage-name prod \
  --endpoint-url http://localhost:4566 > /dev/null 2>&1
echo "✓ API Gateway - POST /appointments (API ID: $API_ID)"

echo ""
echo "=========================================="
echo "Healthcare Demo Ready!"
echo "Test: curl -s -X POST http://localhost:4566/restapis/$API_ID/prod/_user_request_/appointments -H 'Content-Type: application/json' -d '{\"patientId\":\"P-1001\",\"patientName\":\"Raj Kumar\",\"doctor\":\"Dr. Priya\",\"department\":\"Cardiology\",\"status\":\"BOOKED\"}'"
echo "=========================================="

# Deploy consumer Lambda
aws lambda create-function \
  --function-name consumer \
  --runtime nodejs18.x \
  --handler consumer.handler \
  --zip-file fileb:///root/healthcare-demo/consumer.zip \
  --role arn:aws:iam::000000000000:role/lambda-role \
  --endpoint-url http://localhost:4566 > /dev/null 2>&1
echo "✓ Lambda - consumer"
