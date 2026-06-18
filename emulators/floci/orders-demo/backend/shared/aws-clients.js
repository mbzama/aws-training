const AWS = require('aws-sdk');

// Configure AWS SDK for Floci
const isFlocal = process.env.ENVIRONMENT === 'local' || process.env.AWS_ENDPOINT_URL || process.env.IS_LOCAL;

const awsConfig = {
  region: process.env.AWS_REGION || 'us-east-1',
};

if (isFlocal) {
  const endpoint = process.env.AWS_ENDPOINT_URL || 'http://localhost:4566';
  awsConfig.endpoint = endpoint;
  awsConfig.accessKeyId = process.env.AWS_ACCESS_KEY_ID || 'test';
  awsConfig.secretAccessKey = process.env.AWS_SECRET_ACCESS_KEY || 'test';
}

AWS.config.update(awsConfig);

// Initialize AWS Services
const dynamodb = new AWS.DynamoDB.DocumentClient();
const sqs = new AWS.SQS();
const sns = new AWS.SNS();
const s3 = new AWS.S3();
const cognito = new AWS.CognitoIdentityServiceProvider();

module.exports = {
  dynamodb,
  sqs,
  sns,
  s3,
  cognito,
  awsConfig,
  isFlocal,
};
