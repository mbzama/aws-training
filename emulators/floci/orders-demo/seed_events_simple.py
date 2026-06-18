import boto3
from datetime import datetime, timedelta
from decimal import Decimal

# Configure AWS SDK for Floci
aws_config = {
    'region_name': 'us-east-1',
    'endpoint_url': 'http://localhost:4566',
    'aws_access_key_id': 'test',
    'aws_secret_access_key': 'test'
}

dynamodb = boto3.resource('dynamodb', **aws_config)
table = dynamodb.Table('Events')

# Sample events
events = [
    {
        'eventId': 'evt-001',
        'name': 'Tech Conference 2026',
        'description': 'Annual technology conference with industry leaders',
        'date': (datetime.utcnow() + timedelta(days=30)).isoformat(),
        'location': 'T-Hub, Hyderabad',
        'capacity': 500,
        'ticketPrice': Decimal('599'),
        'organizer': 'Tech Events Inc',
        'category': 'Conference'
    },
    {
        'eventId': 'evt-002',
        'name': 'Tech Festival',
        'description': 'Summer technology festival featuring local and international developers',
        'date': (datetime.utcnow() + timedelta(days=45)).isoformat(),
        'location': 'Banglore',
        'capacity': 5000,
        'ticketPrice': Decimal('999'),
        'organizer': 'Tech Events Inc',
        'category': 'Festival'
    },
    {
        'eventId': 'evt-003',
        'name': 'Web Development Workshop',
        'description': 'Hands-on workshop for building modern web applications',
        'date': (datetime.utcnow() + timedelta(days=14)).isoformat(),
        'location': 'Online',
        'capacity': 100,
        'ticketPrice': Decimal('99'),
        'organizer': 'Dev Academy',
        'category': 'Workshop'
    },
    {
        'eventId': 'evt-004',
        'name': 'AI & Machine Learning Summit',
        'description': 'Explore the latest advancements in AI and machine learning',
        'date': (datetime.utcnow() + timedelta(days=60)).isoformat(),
        'location': 'Hyderabad',
        'capacity': 300,
        'ticketPrice': Decimal('399'),
        'organizer': 'AI Innovations Ltd',
        'category': 'Summit'
    },
]

print("Seeding events to DynamoDB...")
for event in events:
    try:
        table.put_item(Item=event)
        print(f"✓ Created event: {event['name']}")
    except Exception as e:
        print(f"✗ Error creating event {event['name']}: {str(e)}")

print("\nEvents seeded successfully!")
print(f"Total events: {len(events)}")
