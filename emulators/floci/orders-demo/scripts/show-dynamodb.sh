#!/bin/bash
set -e

export AWS_ENDPOINT_URL="http://localhost:4566"
export AWS_ACCESS_KEY_ID="test"
export AWS_SECRET_ACCESS_KEY="test"
export AWS_DEFAULT_REGION="us-east-1"

echo "=========================================="
echo "DynamoDB Tables Contents"
echo "=========================================="
echo ""

echo "[Events Table]"
aws dynamodb scan --table-name Events --endpoint-url $AWS_ENDPOINT_URL | jq '.Items[] | {eventId: .eventId.S, name: .name.S, date: .date.S, capacity: .capacity.N, ticketPrice: .ticketPrice.N}'
echo ""

echo "[Bookings Table]"
aws dynamodb scan --table-name Bookings --endpoint-url $AWS_ENDPOINT_URL | jq '.Items[] | {bookingId: .bookingId.S, eventId: .eventId.S, userId: .userId.S, quantity: .quantity.N, totalPrice: .totalPrice.N, status: .status.S, createdAt: .createdAt.S}'
echo ""

echo "=========================================="
echo "Summary"
echo "=========================================="
EVENTS_COUNT=$(aws dynamodb scan --table-name Events --endpoint-url $AWS_ENDPOINT_URL | jq '.Items | length')
BOOKINGS_COUNT=$(aws dynamodb scan --table-name Bookings --endpoint-url $AWS_ENDPOINT_URL | jq '.Items | length')

echo "Events: $EVENTS_COUNT"
echo "Bookings: $BOOKINGS_COUNT"
echo ""
