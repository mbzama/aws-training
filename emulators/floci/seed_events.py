#!/usr/bin/env python3
import boto3
from decimal import Decimal

# AWS Config for Floci
aws_config = {
    'region_name': 'us-east-1',
    'endpoint_url': 'http://localhost:4566',
    'aws_access_key_id': 'test',
    'aws_secret_access_key': 'test'
}

dynamodb = boto3.resource('dynamodb', **aws_config)

events = [
    {
        'eventId': 'event-001',
        'name': 'Summer Music Festival 2026',
        'category': 'Music',
        'ticketPrice': Decimal('99.99'),
        'capacity': Decimal('5000'),
        'ticketsSold': Decimal('1200'),
        'date': '2026-07-15T00:00:00.000Z',
        'location': 'Central Park, NY',
        'description': 'Enjoy live performances from top artists'
    },
    {
        'eventId': 'event-002',
        'name': 'Tech Conference 2026',
        'category': 'Technology',
        'ticketPrice': Decimal('299.99'),
        'capacity': Decimal('3000'),
        'ticketsSold': Decimal('800'),
        'date': '2026-09-20T00:00:00.000Z',
        'location': 'San Francisco, CA',
        'description': 'Network with industry experts and learn about cutting-edge tech'
    },
    {
        'eventId': 'event-003',
        'name': 'Food Carnival 2026',
        'category': 'Food',
        'ticketPrice': Decimal('49.99'),
        'capacity': Decimal('2000'),
        'ticketsSold': Decimal('500'),
        'date': '2026-08-10T00:00:00.000Z',
        'location': 'Downtown, Chicago',
        'description': 'Taste cuisines from around the world'
    },
    {
        'eventId': 'event-004',
        'name': 'Basketball Championship 2026',
        'category': 'Sports',
        'ticketPrice': Decimal('150.00'),
        'capacity': Decimal('20000'),
        'ticketsSold': Decimal('15000'),
        'date': '2026-06-15T00:00:00.000Z',
        'location': 'Madison Square Garden, NY',
        'description': 'Watch the championship finals live'
    }
]

try:
    table = dynamodb.Table('Events')
    for event in events:
        table.put_item(Item=event)
        print("Added: " + event['name'])
    print("\nEvents seeded successfully!")
except Exception as e:
    print("Error seeding events: " + str(e))
