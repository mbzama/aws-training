ROOT=$(aws --endpoint-url=http://localhost:4566 apigateway get-resources --rest-api-id 1e5bd1e7 --query 'items[0].id' --output text)
aws --endpoint-url=http://localhost:4566 apigateway create-resource --rest-api-id 1e5bd1e7 --parent-id $ROOT --path-part appointments
