#!/bin/bash
set -e

echo "Seeding DynamoDB with sample events..."

# Add Event 1
aws dynamodb put-item \
  --table-name Events \
  --item '{"eventId":{"S":"event-001"},"name":{"S":"Summer Music Festival 2026"},"category":{"S":"Music"},"ticketPrice":{"N":"99.99"},"capacity":{"N":"5000"},"ticketsSold":{"N":"1200"},"date":{"S":"2026-07-15T00:00:00.000Z"},"location":{"S":"Central Park, NY"},"description":{"S":"Enjoy live performances from top artists"}}' \
  --endpoint-url $AWS_ENDPOINT_URL

# Add Event 2
aws dynamodb put-item \
  --table-name Events \
  --item '{"eventId":{"S":"event-002"},"name":{"S":"Tech Conference 2026"},"category":{"S":"Technology"},"ticketPrice":{"N":"299.99"},"capacity":{"N":"3000"},"ticketsSold":{"N":"800"},"date":{"S":"2026-09-20T00:00:00.000Z"},"location":{"S":"San Francisco, CA"},"description":{"S":"Network with industry experts and learn about cutting-edge tech"}}' \
  --endpoint-url $AWS_ENDPOINT_URL

# Add Event 3
aws dynamodb put-item \
  --table-name Events \
  --item '{"eventId":{"S":"event-003"},"name":{"S":"Food Carnival 2026"},"category":{"S":"Food"},"ticketPrice":{"N":"49.99"},"capacity":{"N":"2000"},"ticketsSold":{"N":"500"},"date":{"S":"2026-08-10T00:00:00.000Z"},"location":{"S":"Downtown, Chicago"},"description":{"S":"Taste cuisines from around the world"}}' \
  --endpoint-url $AWS_ENDPOINT_URL

# Add Event 4
aws dynamodb put-item \
  --table-name Events \
  --item '{"eventId":{"S":"event-004"},"name":{"S":"Basketball Championship 2026"},"category":{"S":"Sports"},"ticketPrice":{"N":"150.00"},"capacity":{"N":"20000"},"ticketsSold":{"N":"15000"},"date":{"S":"2026-06-15T00:00:00.000Z"},"location":{"S":"Madison Square Garden, NY"},"description":{"S":"Watch the championship finals live"}}' \
  --endpoint-url $AWS_ENDPOINT_URL

echo "✓ Events seeded successfully"
