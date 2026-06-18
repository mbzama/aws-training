aws --endpoint-url=http://localhost:4566 sns create-topic --name patient-notifications
aws --endpoint-url=http://localhost:4566 sqs create-queue --queue-name appointment-queue
