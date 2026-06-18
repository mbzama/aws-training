#!/bin/bash

# Watch DynamoDB Bookings Table
# Refreshes every 2 seconds to show new bookings and status updates

set_color() {
  case $1 in
    PENDING) echo -e "\033[0;33m" ;; # Yellow
    PROCESSING) echo -e "\033[0;36m" ;; # Cyan
    CONFIRMED) echo -e "\033[0;32m" ;; # Green
    *) echo -e "\033[0m" ;; # Reset
  esac
}

reset_color() {
  echo -e "\033[0m"
}

while true; do
  clear
  echo "=========================================="
  echo "DynamoDB: Bookings Table"
  echo "=========================================="
  echo "Last updated: $(date '+%Y-%m-%d %H:%M:%S')"
  echo ""

  RESULT=$(aws dynamodb scan \
    --table-name Bookings \
    --endpoint-url http://localhost:4566 2>/dev/null)

  ITEM_COUNT=$(echo "$RESULT" | jq '.Items | length')

  if [ "$ITEM_COUNT" -eq 0 ]; then
    echo "No bookings yet."
  else
    echo "Total bookings: $ITEM_COUNT"
    echo ""
    echo "$(printf '%-40s %-15s %-40s %-15s' 'Booking ID' 'User ID' 'Event ID' 'Status')"
    echo "$(printf '%-40s %-15s %-40s %-15s' '$(printf "%0.s-" {1..40})' '$(printf "%0.s-" {1..15})' '$(printf "%0.s-" {1..40})' '$(printf "%0.s-" {1..15})')"

    echo "$RESULT" | jq -r '.Items[] |
      "\(.bookingId.S) \(.userId.S) \(.eventId.S) \(.status.S)"' | while read booking_id user_id event_id status; do
      set_color "$status"
      printf '%-40s %-15s %-40s %-15s\n' "$booking_id" "$user_id" "$event_id" "$status"
      reset_color
    done

    echo ""
    echo "Status Breakdown:"
    echo "$RESULT" | jq -r '.Items[].status.S' | sort | uniq -c | while read count status; do
      printf '  %s: %d\n' "$status" "$count"
    done
  fi

  echo ""
  echo "Details:"
  echo "$RESULT" | jq '.Items[] | {
    bookingId: .bookingId.S,
    userId: .userId.S,
    eventId: .eventId.S,
    quantity: .quantity.N,
    totalPrice: .totalPrice.N,
    status: .status.S,
    createdAt: .createdAt.S
  }' 2>/dev/null | head -50

  echo ""
  echo "Refreshing in 2 seconds... (Press Ctrl+C to stop)"
  sleep 2
done
