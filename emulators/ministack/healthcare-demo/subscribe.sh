aws --endpoint-url=http://localhost:4566 sns subscribe \
  --topic-arn arn:aws:sns:us-east-1:000000000000:patient-notifications \
  --protocol sqs \
  --notification-endpoint arn:aws:sqs:us-east-1:000000000000:appointment-queue
