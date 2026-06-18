from flask import Flask, jsonify, request
from flask_cors import CORS
from functools import wraps
import boto3
import json
import uuid
import logging
import os
from datetime import datetime
from decimal import Decimal
from io import BytesIO
from dotenv import load_dotenv

load_dotenv()
try:
    from reportlab.lib.pagesizes import letter
    from reportlab.lib import colors
    from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle
    from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
    from reportlab.lib.units import inch
    HAS_REPORTLAB = True
except ImportError:
    HAS_REPORTLAB = False

app = Flask(__name__)
CORS(app, resources={
    r"/*": {
        "origins": "*",
        "methods": ["GET", "POST", "OPTIONS", "DELETE", "PUT"],
        "allow_headers": ["Content-Type", "Authorization"],
        "supports_credentials": True
    }
})

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('app.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# Rate limiting disabled for local development
# In production, use: Limiter(app=app, key_func=get_remote_address, default_limits=["200 per day", "50 per hour"])

# Authentication decorator
def require_auth(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        # Skip auth for OPTIONS requests (CORS preflight)
        if request.method == 'OPTIONS':
            return f(*args, **kwargs)

        auth_header = request.headers.get('Authorization')
        if not auth_header or not auth_header.startswith('Bearer '):
            return jsonify({'error': 'Missing or invalid authorization header'}), 401

        token = auth_header.split(' ')[1]
        if not token or len(token) < 10:
            return jsonify({'error': 'Invalid token'}), 401

        # In production: validate against Cognito public keys
        # For demo: accept any token (auth done by Cognito on frontend)
        return f(*args, **kwargs)
    return decorated_function

# Configure AWS SDK for Floci
aws_config = {
    'region_name': 'us-east-1',
    'endpoint_url': 'http://localhost:4566',
    'aws_access_key_id': 'test',
    'aws_secret_access_key': 'test'
}

# AWS clients pointing to Floci
dynamodb = boto3.resource('dynamodb', **aws_config)
s3 = boto3.client('s3', **aws_config)
sqs = boto3.client('sqs', **aws_config)
sns = boto3.client('sns', **aws_config)
cognito = boto3.client('cognito-idp', **aws_config)

def generate_ticket_pdf(booking_id, event_name, quantity, total_price, user_email):
    """Generate a simple ticket PDF"""
    if not HAS_REPORTLAB:
        return None

    try:
        pdf_buffer = BytesIO()
        doc = SimpleDocTemplate(pdf_buffer, pagesize=letter)
        elements = []
        styles = getSampleStyleSheet()

        title_style = ParagraphStyle(
            'CustomTitle',
            parent=styles['Heading1'],
            fontSize=24,
            textColor=colors.HexColor('#2d3748'),
            spaceAfter=30,
            alignment=1
        )

        elements.append(Paragraph('EVENT TICKET', title_style))
        elements.append(Spacer(1, 0.3*inch))

        data = [
            ['Booking ID:', booking_id],
            ['Event:', event_name],
            ['Tickets:', str(quantity)],
            ['Total Price:', f'${total_price:.2f}'],
            ['Email:', user_email],
            ['Date Issued:', datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')],
        ]

        table = Table(data, colWidths=[2*inch, 3*inch])
        table.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (0, -1), colors.lightgrey),
            ('TEXTCOLOR', (0, 0), (-1, -1), colors.black),
            ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
            ('FONTNAME', (0, 0), (0, -1), 'Helvetica-Bold'),
            ('FONTSIZE', (0, 0), (-1, -1), 11),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 12),
            ('GRID', (0, 0), (-1, -1), 1, colors.black),
        ]))

        elements.append(table)
        elements.append(Spacer(1, 0.5*inch))
        elements.append(Paragraph('✓ This is your event ticket. Please bring it to the event.', styles['Normal']))

        doc.build(elements)
        pdf_buffer.seek(0)
        return pdf_buffer.getvalue()
    except Exception as e:
        logger.warning(f"PDF generation failed: {str(e)}")
        return None

def upload_ticket_to_s3(booking_id, pdf_content):
    """Upload ticket PDF to S3"""
    try:
        key = f"tickets/{booking_id}.pdf"
        s3.put_object(
            Bucket='event-tickets-000000000000',
            Key=key,
            Body=pdf_content,
            ContentType='application/pdf'
        )
        logger.info(f"Ticket uploaded to S3: {key}")
        return key
    except Exception as e:
        logger.warning(f"S3 upload failed: {str(e)}")
        return None

@app.route('/events', methods=['GET'])
def get_events():
    """Get all events from DynamoDB"""
    try:
        table = dynamodb.Table('Events')
        response = table.scan()
        events = response.get('Items', [])
        return jsonify({'events': events})
    except Exception as e:
        logger.error(f"DynamoDB error: {str(e)}")
        return jsonify({'error': str(e), 'events': []}), 500

@app.route('/book', methods=['POST', 'OPTIONS'])
@require_auth
def book_event():
    """Book an event - stores booking in DynamoDB, queues message to SQS, publishes to SNS"""
    if request.method == 'OPTIONS':
        return '', 200

    try:
        data = request.get_json()
        event_id = data.get('eventId')
        quantity = int(data.get('quantity', 1))
        user_email = data.get('userEmail', 'demo@example.com')

        if not all([event_id, quantity, user_email]):
            return jsonify({'error': 'Missing required fields'}), 400

        # Get event details from DynamoDB
        events_table = dynamodb.Table('Events')
        event_response = events_table.get_item(Key={'eventId': event_id})
        event = event_response.get('Item')

        if not event:
            return jsonify({'error': 'Event not found'}), 404

        # Generate booking
        booking_id = f"BOOK-{uuid.uuid4().hex[:8].upper()}"
        ticket_price = event.get('ticketPrice', Decimal('0'))
        if isinstance(ticket_price, float):
            ticket_price = Decimal(str(ticket_price))
        total_price = ticket_price * Decimal(str(quantity))
        booking_timestamp = datetime.utcnow().isoformat()

        # Create booking record
        booking = {
            'bookingId': booking_id,
            'eventId': event_id,
            'userId': user_email,
            'userEmail': user_email,
            'quantity': Decimal(str(quantity)),
            'totalPrice': Decimal(str(total_price)),
            'status': 'CONFIRMED',
            'createdAt': booking_timestamp,
            'eventName': event.get('name', 'Event')
        }

        # 1. Store booking in DynamoDB
        bookings_table = dynamodb.Table('Bookings')
        bookings_table.put_item(Item=booking)
        logger.info(f"Booking saved to DynamoDB: {booking_id}")

        # 2. Queue message to SQS for ticket generation
        try:
            logger.info(f"Getting SQS queue URL...")
            queue_url = get_queue_url('BookingQueue')
            logger.info(f"Queue URL: {queue_url}")

            message_body = {
                'bookingId': booking_id,
                'eventId': event_id,
                'userEmail': user_email,
                'quantity': quantity,
                'eventName': event.get('name'),
                'totalPrice': float(total_price) if isinstance(total_price, Decimal) else total_price
            }
            logger.info(f"Sending message to SQS: {message_body}")

            response = sqs.send_message(
                QueueUrl=queue_url,
                MessageBody=json.dumps(message_body)
            )
            logger.info(f"✓ Message queued to SQS: {booking_id} (MessageId: {response.get('MessageId')})")
        except Exception as e:
            logger.error(f"✗ SQS queue failed: {str(e)}")
            import traceback
            logger.error(traceback.format_exc())

        # 3. Publish to SNS notifications
        try:
            topic_arn = os.environ.get('SNS_TOPIC_ARN')
            sns.publish(
                TopicArn=topic_arn,
                Subject=f'Booking Confirmed: {event.get("name")}',
                Message=f'''
Booking ID: {booking_id}
Event: {event.get('name')}
Tickets: {quantity}
Total Price: ${total_price:.2f}
Customer: {user_email}
Status: CONFIRMED
Created: {booking_timestamp}
                '''
            )
            logger.info(f"Notification published to SNS: {booking_id}")
        except Exception as e:
            logger.warning(f"SNS publish failed: {str(e)}")

        # 4. PDF generation is handled async by worker
        logger.info(f"PDF generation queued for worker processing: {booking_id}")

        return jsonify({
            'success': True,
            'bookingId': booking_id,
            'eventId': event_id,
            'quantity': quantity,
            'totalPrice': float(total_price),
            'status': 'CONFIRMED'
        }), 201

    except Exception as e:
        logger.error(f"Booking error: {str(e)}")
        return jsonify({'error': str(e)}), 500

@app.route('/history', methods=['GET'])
def get_history():
    """Get booking history from DynamoDB"""
    try:
        table = dynamodb.Table('Bookings')
        response = table.scan()
        bookings = response.get('Items', [])
        return jsonify({'bookings': bookings})
    except Exception as e:
        logger.error(f"DynamoDB error: {str(e)}")
        return jsonify({'error': str(e), 'bookings': []}), 500

@app.route('/dynamodb-contents', methods=['GET'])
def dynamodb_contents():
    """View DynamoDB tables contents"""
    try:
        contents = {}

        # Events table
        events_table = dynamodb.Table('Events')
        events_response = events_table.scan()
        contents['Events'] = {
            'count': len(events_response.get('Items', [])),
            'items': events_response.get('Items', [])
        }

        # Bookings table
        bookings_table = dynamodb.Table('Bookings')
        bookings_response = bookings_table.scan()
        contents['Bookings'] = {
            'count': len(bookings_response.get('Items', [])),
            'items': bookings_response.get('Items', [])
        }

        return jsonify(contents)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/s3-contents', methods=['GET'])
def s3_contents():
    """View S3 tickets bucket contents"""
    try:
        response = s3.list_objects_v2(Bucket='event-tickets-000000000000')
        objects = response.get('Contents', [])
        tickets = []
        for obj in objects:
            tickets.append({
                'key': obj['Key'],
                'size': obj['Size'],
                'modified': str(obj['LastModified'])
            })
        return jsonify({
            'bucket': 'event-tickets-000000000000',
            'count': len(tickets),
            'tickets': tickets
        })
    except Exception as e:
        return jsonify({'error': str(e), 'tickets': []}), 500

@app.route('/sqs-contents', methods=['GET'])
def sqs_contents():
    """View SQS queue messages"""
    try:
        queue_url = get_queue_url('BookingQueue')
        response = sqs.get_queue_attributes(
            QueueUrl=queue_url,
            AttributeNames=['ApproximateNumberOfMessages']
        )
        msg_count = int(response['Attributes'].get('ApproximateNumberOfMessages', 0))
        return jsonify({
            'queue': 'BookingQueue',
            'approximateMessageCount': msg_count,
            'queueUrl': queue_url
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/sns-contents', methods=['GET'])
def sns_contents():
    """View SNS topic information"""
    try:
        topic_arn = get_topic_arn('BookingNotifications')
        response = sns.get_topic_attributes(TopicArn=topic_arn)
        attrs = response.get('Attributes', {})
        return jsonify({
            'topic': 'BookingNotifications',
            'topicArn': topic_arn,
            'subscriptionCount': int(attrs.get('SubscriptionsConfirmed', 0)),
            'messageCount': int(attrs.get('SubscriptionsPending', 0))
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/health', methods=['GET'])
def health():
    """Health check"""
    return jsonify({'status': 'ok'}), 200

@app.route('/auth/signin', methods=['POST', 'OPTIONS'])
def signin():
    """Sign in user with email and password via Cognito"""
    if request.method == 'OPTIONS':
        return '', 200

    try:
        data = request.get_json()
        email = data.get('email')
        password = data.get('password')

        if not email or not password:
            return jsonify({'error': 'Email and password required'}), 400

        user_pool_id = os.environ.get('COGNITO_USER_POOL_ID')
        client_id = os.environ.get('COGNITO_CLIENT_ID')

        if not user_pool_id or not client_id:
            return jsonify({'error': 'Cognito not configured'}), 500

        response = cognito.initiate_auth(
            ClientId=client_id,
            AuthFlow='USER_PASSWORD_AUTH',
            AuthParameters={
                'USERNAME': email,
                'PASSWORD': password
            }
        )

        auth_result = response.get('AuthenticationResult', {})
        return jsonify({
            'success': True,
            'accessToken': auth_result.get('AccessToken'),
            'idToken': auth_result.get('IdToken'),
            'refreshToken': auth_result.get('RefreshToken'),
            'expiresIn': auth_result.get('ExpiresIn')
        }), 200

    except cognito.exceptions.NotAuthorizedException:
        return jsonify({'error': 'Invalid credentials'}), 401
    except cognito.exceptions.UserNotFoundException:
        return jsonify({'error': 'User not found'}), 401
    except Exception as e:
        logger.error(f"Sign in error: {str(e)}")
        return jsonify({'error': 'Sign in failed', 'details': str(e)}), 500

@app.route('/auth/signup', methods=['POST', 'OPTIONS'])
def signup():
    """Sign up user via Cognito"""
    if request.method == 'OPTIONS':
        return '', 200

    try:
        data = request.get_json()
        email = data.get('email')
        password = data.get('password')
        name = data.get('name')

        if not all([email, password, name]):
            return jsonify({'error': 'Email, password, and name required'}), 400

        user_pool_id = os.environ.get('COGNITO_USER_POOL_ID')

        if not user_pool_id:
            return jsonify({'error': 'Cognito not configured'}), 500

        response = cognito.admin_create_user(
            UserPoolId=user_pool_id,
            Username=email,
            UserAttributes=[
                {'Name': 'email', 'Value': email},
                {'Name': 'name', 'Value': name},
                {'Name': 'email_verified', 'Value': 'true'}
            ],
            TemporaryPassword=password,
            MessageAction='SUPPRESS'
        )

        # Set permanent password
        cognito.admin_set_user_password(
            UserPoolId=user_pool_id,
            Username=email,
            Password=password,
            Permanent=True
        )

        return jsonify({
            'success': True,
            'userSub': response['User']['Username'],
            'username': email
        }), 201

    except cognito.exceptions.UsernameExistsException:
        return jsonify({'error': 'User already exists'}), 409
    except Exception as e:
        logger.error(f"Sign up error: {str(e)}")
        return jsonify({'error': 'Sign up failed', 'details': str(e)}), 500

@app.route('/auth/signout', methods=['POST', 'OPTIONS'])
def signout():
    """Sign out user (invalidate tokens server-side if needed)"""
    if request.method == 'OPTIONS':
        return '', 200

    try:
        auth_header = request.headers.get('Authorization')
        if auth_header and auth_header.startswith('Bearer '):
            token = auth_header.split(' ')[1]
            logger.info(f"User signed out")

        return jsonify({'success': True}), 200
    except Exception as e:
        logger.warning(f"Sign out error: {str(e)}")
        return jsonify({'success': True}), 200

def get_queue_url(queue_name):
    """Get SQS queue URL"""
    try:
        response = sqs.get_queue_url(QueueName=queue_name)
        return response['QueueUrl']
    except:
        return f"http://localhost:4566/000000000000/{queue_name}"

def get_topic_arn(topic_name):
    """Get SNS topic ARN"""
    try:
        response = sns.list_topics()
        for topic in response.get('Topics', []):
            if topic_name in topic['TopicArn']:
                return topic['TopicArn']
    except:
        pass
    return f"arn:aws:sns:us-east-1:000000000000:{topic_name}"

if __name__ == '__main__':
    print('[OK] Flask API running on http://localhost:5000')
    print('[OK] Auth: POST http://localhost:5000/auth/signin')
    print('[OK] Auth: POST http://localhost:5000/auth/signup')
    print('[OK] Auth: POST http://localhost:5000/auth/signout')
    print('[OK] Events: GET http://localhost:5000/events')
    print('[OK] Book: POST http://localhost:5000/book')
    print('[OK] History: GET http://localhost:5000/history')
    print('[OK] DynamoDB: GET http://localhost:5000/dynamodb-contents')
    print('[OK] S3: GET http://localhost:5000/s3-contents')
    print('[OK] SQS: GET http://localhost:5000/sqs-contents')
    print('[OK] SNS: GET http://localhost:5000/sns-contents')
    app.run(debug=True, port=5000)
