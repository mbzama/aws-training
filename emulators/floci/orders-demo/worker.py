#!/usr/bin/env python3
"""
Async Worker for Event Booking Platform
Consumes SQS messages and generates PDF tickets
"""

import boto3
import json
import logging
import time
from datetime import datetime
from io import BytesIO
from decimal import Decimal

try:
    from reportlab.lib.pagesizes import letter
    from reportlab.lib import colors
    from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle
    from reportlab.lib.styles import getSampleStyleSheet
    from reportlab.lib.units import inch
    HAS_REPORTLAB = True
except ImportError:
    HAS_REPORTLAB = False

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('worker.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# AWS Config for Floci
aws_config = {
    'region_name': 'us-east-1',
    'endpoint_url': 'http://localhost:4566',
    'aws_access_key_id': 'test',
    'aws_secret_access_key': 'test'
}

# AWS clients
sqs = boto3.client('sqs', **aws_config)
s3 = boto3.client('s3', **aws_config)
dynamodb = boto3.resource('dynamodb', **aws_config)

def get_queue_url():
    """Get SQS queue URL"""
    try:
        response = sqs.get_queue_url(QueueName='BookingQueue')
        return response['QueueUrl']
    except:
        return 'http://localhost:4566/000000000000/BookingQueue'

def generate_ticket_pdf(booking_id, event_name, quantity, total_price, user_email):
    """Generate PDF ticket"""
    if not HAS_REPORTLAB:
        logger.warning("ReportLab not available, skipping PDF generation")
        return None

    try:
        pdf_buffer = BytesIO()
        doc = SimpleDocTemplate(pdf_buffer, pagesize=letter)
        elements = []
        styles = getSampleStyleSheet()

        elements.append(Paragraph('EVENT TICKET', styles['Heading1']))
        elements.append(Spacer(1, 0.3*inch))

        # Convert Decimal to float if needed
        price_display = float(total_price) if isinstance(total_price, Decimal) else total_price

        data = [
            ['Booking ID:', booking_id],
            ['Event:', event_name],
            ['Tickets:', str(quantity)],
            ['Total Price:', f'${price_display:.2f}'],
            ['Email:', user_email],
            ['Generated:', time.strftime('%Y-%m-%d %H:%M:%S')],
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
        elements.append(Paragraph('This is your event ticket. Please bring it to the event.', styles['Normal']))

        doc.build(elements)
        pdf_buffer.seek(0)
        return pdf_buffer.getvalue()
    except Exception as e:
        logger.error(f"PDF generation failed: {str(e)}")
        return None

def upload_ticket_to_s3(booking_id, pdf_content):
    """Upload ticket to S3"""
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
        logger.error(f"S3 upload failed: {str(e)}")
        return None

def update_booking_status(booking_id, user_id, status):
    """Update booking status in DynamoDB"""
    try:
        table = dynamodb.Table('Bookings')
        table.update_item(
            Key={
                'userId': user_id,
                'bookingId': booking_id
            },
            UpdateExpression='SET #status = :status, updatedAt = :timestamp',
            ExpressionAttributeNames={'#status': 'status'},
            ExpressionAttributeValues={
                ':status': status,
                ':timestamp': datetime.utcnow().isoformat() + 'Z'
            }
        )
        logger.info(f"Booking {booking_id} status updated to {status}")
    except Exception as e:
        logger.error(f"DynamoDB update failed: {str(e)}")

def process_message(message):
    """Process a single SQS message"""
    try:
        body = json.loads(message['Body'])
        booking_id = body.get('bookingId')
        event_name = body.get('eventName')
        quantity = body.get('quantity')
        total_price = body.get('totalPrice')
        user_email = body.get('userEmail')

        logger.info(f"Processing booking: {booking_id}")

        # Generate PDF
        pdf_content = generate_ticket_pdf(booking_id, event_name, quantity, total_price, user_email)
        
        if pdf_content:
            # Upload to S3
            upload_ticket_to_s3(booking_id, pdf_content)
            
            # Update booking status to CONFIRMED
            update_booking_status(booking_id, user_email, 'CONFIRMED')
            logger.info(f"Booking {booking_id} completed successfully")
            return True
        else:
            logger.warning(f"PDF generation failed for {booking_id}")
            return False

    except Exception as e:
        logger.error(f"Message processing failed: {str(e)}")
        return False

def main():
    """Main worker loop"""
    logger.info("="*60)
    logger.info("Starting Event Booking Worker...")
    logger.info("="*60)

    queue_url = get_queue_url()
    logger.info(f"Queue URL: {queue_url}")

    poll_count = 0
    message_count = 0

    while True:
        try:
            poll_count += 1

            # Receive messages
            response = sqs.receive_message(
                QueueUrl=queue_url,
                MaxNumberOfMessages=10,
                WaitTimeSeconds=10,
                VisibilityTimeout=60
            )

            messages = response.get('Messages', [])

            if messages:
                logger.info(f"[Poll #{poll_count}] Received {len(messages)} message(s)")
                for message in messages:
                    try:
                        message_count += 1
                        # Process message
                        success = process_message(message)

                        if success:
                            # Delete message from queue
                            sqs.delete_message(
                                QueueUrl=queue_url,
                                ReceiptHandle=message['ReceiptHandle']
                            )
                            logger.info(f"✓ Message deleted from queue")
                        else:
                            logger.warning(f"✗ Message processing failed")
                    except Exception as e:
                        logger.error(f"✗ Error processing message: {str(e)}")
                        # Message will reappear after visibility timeout
            else:
                if poll_count % 6 == 0:  # Log every 60 seconds (6 polls × 10 sec)
                    logger.info(f"[Poll #{poll_count}] Waiting for messages... (processed {message_count} total)")

        except KeyboardInterrupt:
            logger.info("Worker stopping...")
            break
        except Exception as e:
            logger.error(f"✗ Queue polling error: {str(e)}")
            time.sleep(5)

if __name__ == '__main__':
    main()
