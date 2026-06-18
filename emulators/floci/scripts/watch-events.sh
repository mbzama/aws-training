#!/bin/bash

# Watch DynamoDB Events Table
# Shows all available events and their details

while true; do
  clear
  echo "=========================================="
  echo "DynamoDB: Events Table"
  echo "=========================================="
  echo "Last updated: $(date '+%Y-%m-%d %H:%M:%S')"
  echo ""

  RESULT=$(aws dynamodb scan \
    --table-name Events \
    --endpoint-url http://localhost:4566 2>/dev/null)

  ITEM_COUNT=$(echo "$RESULT" | jq '.Items | length')

  if [ "$ITEM_COUNT" -eq 0 ]; then
    echo "No events found."
  else
    echo "Total events: $ITEM_COUNT"
    echo ""
    echo "$(printf '%-12s %-35s %-15s %-20s' 'Event ID' 'Event Name' 'Date' 'Ticket Price')"
    echo "$(printf '%-12s %-35s %-15s %-20s' '$(printf "%0.s-" {1..12})' '$(printf "%0.s-" {1..35})' '$(printf "%0.s-" {1..15})' '$(printf "%0.s-" {1..20})')"

    echo "$RESULT" | jq -r '.Items[] |
      "\(.eventId.S) \(.name.S) \(.date.S) \(.ticketPrice.N)"' | while read event_id name date price; do
      printf '%-12s %-35s %-15s $%-19s\n' "$event_id" "$name" "$date" "$price"
    done
  fi

  echo ""
  echo "Full Details:"
  echo "$RESULT" | jq '.Items[] | {
    eventId: .eventId.S,
    name: .name.S,
    date: .date.S,
    location: .location.S,
    category: .category.S,
    capacity: .capacity.N,
    ticketPrice: .ticketPrice.N,
    description: .description.S
  }' 2>/dev/null | head -100

  echo ""
  echo "Refreshing in 3 seconds... (Press Ctrl+C to stop)"
  sleep 3
done
