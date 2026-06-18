# Testing Guide

## Table of Contents
1. [Unit Testing](#unit-testing)
2. [Integration Testing](#integration-testing)
3. [End-to-End Testing](#end-to-end-testing)
4. [Performance Testing](#performance-testing)
5. [Security Testing](#security-testing)

## Unit Testing

### Backend Lambda Functions

**Testing Framework:** Jest

**Install test dependencies:**
```bash
cd backend
npm install --save-dev jest aws-sdk-mock
```

**Test file structure:**
```
backend/
├── __tests__/
│   ├── booking-lambda.test.js
│   ├── events-lambda.test.js
│   ├── history-lambda.test.js
│   └── ticket-generator-lambda.test.js
```

### Example Unit Test

**File:** `backend/__tests__/booking-lambda.test.js`
```javascript
const AWS = require('aws-sdk-mock');
const { handler } = require('../booking-lambda/index');

describe('Booking Lambda', () => {
  beforeEach(() => {
    AWS.cleanUp();
  });

  test('should create booking successfully', async () => {
    AWS.mock('DynamoDB.DocumentClient', 'put', () => {
      return Promise.resolve({ Item: {} });
    });

    AWS.mock('SQS', 'sendMessage', () => {
      return Promise.resolve({ MessageId: 'msg-123' });
    });

    AWS.mock('SNS', 'publish', () => {
      return Promise.resolve({ MessageId: 'sns-123' });
    });

    const event = {
      httpMethod: 'POST',
      path: '/book',
      body: JSON.stringify({
        eventId: 'event-001',
        quantity: 2,
      }),
      requestContext: {
        authorizer: {
          claims: {
            sub: 'user123',
            email: 'user@example.com',
          },
        },
      },
    };

    const result = await handler(event);

    expect(result.statusCode).toBe(200);
    expect(JSON.parse(result.body).success).toBe(true);
  });

  test('should validate required fields', async () => {
    const event = {
      httpMethod: 'POST',
      path: '/book',
      body: JSON.stringify({}), // Missing eventId and quantity
      requestContext: {
        authorizer: {
          claims: {
            sub: 'user123',
          },
        },
      },
    };

    const result = await handler(event);

    expect(result.statusCode).toBe(400);
    expect(JSON.parse(result.body).error.code).toBe('VALIDATION_ERROR');
  });
});
```

**Run tests:**
```bash
npm test
```

## Integration Testing

### Test Events Lambda

```bash
# Set AWS endpoint
export AWS_ENDPOINT_URL=http://localhost:4566

# Get all events
curl -X GET http://localhost:3000/api/events

# Search events
curl -X GET "http://localhost:3000/api/events/search?q=music"

# Get event details
curl -X GET http://localhost:3000/api/events/event-001
```

### Test Booking Lambda

```bash
# Get JWT token via Cognito user pool
USER_POOL_ID=$(aws cognito-idp list-user-pools --max-results 10 --endpoint-url http://localhost:4566 | jq -r '.UserPools[0].Id')
CLIENT_ID=$(aws cognito-idp list-user-pool-clients --user-pool-id $USER_POOL_ID --endpoint-url http://localhost:4566 | jq -r '.UserPoolClients[0].ClientId')
TOKEN=$(aws cognito-idp admin-initiate-auth --user-pool-id $USER_POOL_ID --client-id $CLIENT_ID --auth-flow ADMIN_NO_SRP_AUTH --auth-parameters USERNAME=demo@example.com,PASSWORD=Demo@123456 --endpoint-url http://localhost:4566 | jq -r '.AuthenticationResult.IdToken')

# Book tickets
curl -X POST http://localhost:3000/api/book \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "eventId": "event-001",
    "quantity": 2
  }'
```

### Test History Lambda

```bash
# Get booking history
curl -X GET http://localhost:3000/api/history \
  -H "Authorization: Bearer $TOKEN"
```

### Verify DynamoDB

```bash
# Check bookings table
aws dynamodb scan --table-name Bookings \
  --endpoint-url http://localhost:4566

# Check booking for specific user
aws dynamodb query \
  --table-name Bookings \
  --key-condition-expression "userId = :userId" \
  --expression-attribute-values '{":userId":{"S":"user123"}}' \
  --endpoint-url http://localhost:4566
```

### Verify SQS

```bash
# Check queue messages
aws sqs receive-message \
  --queue-url http://localhost:4566/000000000000/BookingQueue \
  --endpoint-url http://localhost:4566

# Check DLQ messages
aws sqs receive-message \
  --queue-url http://localhost:4566/000000000000/BookingQueueDLQ \
  --endpoint-url http://localhost:4566
```

### Verify SNS

```bash
# List topics
aws sns list-topics --endpoint-url http://localhost:4566

# List subscriptions
aws sns list-subscriptions --endpoint-url http://localhost:4566

# Publish test message
aws sns publish \
  --topic-arn arn:aws:sns:us-east-1:000000000000:BookingNotifications \
  --message "Test notification" \
  --endpoint-url http://localhost:4566
```

## End-to-End Testing

### Complete User Journey

**1. Sign Up:**
```bash
curl -X POST http://localhost:3000/api/auth/signup \
  -H "Content-Type: application/json" \
  -d '{
    "email": "newuser@example.com",
    "password": "NewPassword123!",
    "name": "New User"
  }'
```

**2. Sign In:**
```bash
curl -X POST http://localhost:3000/api/auth/signin \
  -H "Content-Type: application/json" \
  -d '{
    "email": "demo@example.com",
    "password": "Demo@123456"
  }'
```

**3. Browse Events:**
```bash
curl -X GET http://localhost:3000/api/events
```

**4. Get Event Details:**
```bash
curl -X GET http://localhost:3000/api/events/event-001
```

**5. Book Tickets:**
```bash
curl -X POST http://localhost:3000/api/book \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "eventId": "event-001",
    "quantity": 2
  }'
```

**6. View Booking History:**
```bash
curl -X GET http://localhost:3000/api/history \
  -H "Authorization: Bearer $TOKEN"
```

**7. Download Ticket:**
```bash
# Wait for ticket generation (check booking status)
curl -X GET http://localhost:3000/api/history \
  -H "Authorization: Bearer $TOKEN" | jq '.bookings[0].ticketUrl'
```

### Frontend End-to-End Tests

**Using Playwright or Cypress:**

```javascript
// cypress/e2e/booking.cy.js
describe('Event Booking E2E Test', () => {
  beforeEach(() => {
    cy.visit('http://localhost:3000');
  });

  it('should complete booking flow', () => {
    // Login
    cy.contains('Sign In').click();
    cy.get('input[type="email"]').type('demo@example.com');
    cy.get('input[type="password"]').type('Demo@123456');
    cy.contains('Sign In').click();

    // Browse events
    cy.contains('Available Events').should('be.visible');

    // Book tickets
    cy.contains('Summer Music Festival').should('be.visible');
    cy.contains('Book Tickets').first().click();

    // Select quantity
    cy.get('select#quantity').select('2');

    // Confirm booking
    cy.contains('Confirm Booking').click();

    // Verify success
    cy.contains('Booking Confirmed').should('be.visible');

    // View history
    cy.contains('View Booking History').click();
    cy.contains('My Bookings').should('be.visible');
  });
});
```

**Run E2E tests:**
```bash
npm run cypress:run
```

## Performance Testing

### Load Testing with Apache JMeter

**Install JMeter:**
```bash
# macOS
brew install jmeter

# Windows (download from https://jmeter.apache.org/)
```

**Create test plan:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<jmeterTestPlan version="1.2">
  <hashTree>
    <TestPlan>
      <elementProp name="TestPlan.user_defined_variables"/>
    </TestPlan>
    <ThreadGroup guiclass="ThreadGroupGui" testname="Event Booking Load Test">
      <elementProp name="ThreadGroup.main_controller"/>
      <stringProp name="ThreadGroup.num_threads">100</stringProp>
      <stringProp name="ThreadGroup.ramp_time">10</stringProp>
      <sampler class="HTTPSampler" testname="Get Events">
        <elementProp name="HTTPsampler.Arguments" class="Arguments"/>
        <stringProp name="HTTPSampler.domain">localhost</stringProp>
        <stringProp name="HTTPSampler.port">3000</stringProp>
        <stringProp name="HTTPSampler.protocol">http</stringProp>
        <stringProp name="HTTPSampler.path">/api/events</stringProp>
        <stringProp name="HTTPSampler.method">GET</stringProp>
      </sampler>
    </ThreadGroup>
  </hashTree>
</jmeterTestPlan>
```

**Run load test:**
```bash
jmeter -n -t load-test.jmx -l results.jtl -j jmeter.log
```

### Latency Testing

**Test API response time:**
```bash
# Single request timing
time curl -X GET http://localhost:3000/api/events

# Multiple concurrent requests
ab -n 100 -c 10 http://localhost:3000/api/events
```

### Database Query Performance

**Check DynamoDB performance:**
```bash
# Query with timing
time aws dynamodb query \
  --table-name Bookings \
  --key-condition-expression "userId = :userId" \
  --expression-attribute-values '{":userId":{"S":"user123"}}' \
  --endpoint-url http://localhost:4566
```

## Security Testing

### OWASP Top 10

**1. SQL Injection Testing:**
```bash
# Test with SQL injection payload
curl -X GET "http://localhost:3000/api/events/search?q=event%27%20OR%20%271%27=%271"
```

**Expected:** Sanitized or rejected

**2. XSS Testing:**
```bash
# Test with XSS payload
curl -X POST http://localhost:3000/api/book \
  -H "Content-Type: application/json" \
  -d '{
    "eventId": "<script>alert(1)</script>",
    "quantity": 1
  }'
```

**Expected:** Validation error

**3. Authentication Testing:**
```bash
# Test without authentication
curl -X GET http://localhost:3000/api/history

# Expected: 401 Unauthorized
```

**4. Authorization Testing:**
```bash
# User 1 tries to access User 2's bookings
# (This should fail - need proper audit)
```

### CORS Testing

```bash
# Check CORS headers
curl -i -X OPTIONS http://localhost:3000/api/events \
  -H "Origin: http://malicious.com" \
  -H "Access-Control-Request-Method: GET"
```

### JWT Token Testing

```bash
# Test with expired token
curl -X GET http://localhost:3000/api/history \
  -H "Authorization: Bearer EXPIRED_TOKEN"

# Expected: 401 Unauthorized
```

## Continuous Integration

### GitHub Actions Workflow

**File:** `.github/workflows/test.yml`
```yaml
name: Test and Deploy

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    services:
      localstack:
        image: localstack/localstack:latest
        ports:
          - 4566:4566

    steps:
    - uses: actions/checkout@v3
    
    - name: Setup Node.js
      uses: actions/setup-node@v3
      with:
        node-version: '22'

    - name: Install backend dependencies
      run: cd backend && npm install

    - name: Run backend tests
      run: cd backend && npm test

    - name: Build backend
      run: cd backend && npm run build

    - name: Install frontend dependencies
      run: cd frontend && npm install

    - name: Run frontend tests
      run: cd frontend && npm test

    - name: Build frontend
      run: cd frontend && npm run build

  integration-test:
    needs: test
    runs-on: ubuntu-latest
    services:
      localstack:
        image: localstack/localstack:latest
        ports:
          - 4566:4566

    steps:
    - uses: actions/checkout@v3
    
    - name: Deploy to LocalStack
      run: |
        cd backend
        sam build
        sam deploy --no-confirm-changeset

    - name: Run integration tests
      run: npm run test:integration
```

## Test Results

### Sample Test Report

```
Test Summary Report
==================

Unit Tests:
  Events Lambda:        12 passed, 0 failed
  Booking Lambda:       15 passed, 0 failed
  History Lambda:       10 passed, 0 failed
  Ticket Generator:     8 passed, 0 failed
  ────────────────────────────────
  Total:                45 passed, 0 failed

Integration Tests:
  API Endpoints:        8 passed, 0 failed
  DynamoDB:             5 passed, 0 failed
  SQS Queue:            4 passed, 0 failed
  SNS Topic:            3 passed, 0 failed
  ────────────────────────────────
  Total:                20 passed, 0 failed

E2E Tests:
  User Authentication:  Passed
  Event Discovery:      Passed
  Ticket Booking:       Passed
  Booking History:      Passed
  ────────────────────────────────
  Total:                4 passed, 0 failed

Performance Tests:
  Response Time (p50):  45ms
  Response Time (p99):  120ms
  Throughput:           1000 req/s
  Database Query:       12ms avg

Security Tests:
  SQL Injection:        Blocked
  XSS:                  Blocked
  CORS:                 Configured
  JWT Validation:       Passed

Overall: ✓ All tests passed
```

## Automated Test Execution

**Run all tests:**
```bash
# Backend tests
cd backend
npm test

# Frontend tests
cd ../frontend
npm test

# Integration tests
npm run test:integration

# E2E tests
npm run test:e2e
```

**Generate coverage reports:**
```bash
npm run test:coverage
```

**Expected:** >80% code coverage

For detailed test scripts, see package.json files in each directory.
