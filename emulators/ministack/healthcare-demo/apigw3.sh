aws --endpoint-url=http://localhost:4566 apigateway put-method --rest-api-id 1e5bd1e7 --resource-id 928763c6 --http-method POST --authorization-type NONE

aws --endpoint-url=http://localhost:4566 apigateway put-integration --rest-api-id 1e5bd1e7 --resource-id 928763c6 --http-method POST --type AWS_PROXY --integration-http-method POST --uri arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:000000000000:function:producer/invocations

aws --endpoint-url=http://localhost:4566 apigateway create-deployment --rest-api-id 1e5bd1e7 --stage-name prod
