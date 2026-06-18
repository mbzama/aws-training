const { v4: uuidv4 } = require('uuid');
const logger = require('../shared/logger');
const { dynamodb, sqs } = require('../shared/aws-clients');
const { BOOKING_STATUS } = require('../shared/booking-service');

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type',
  'Access-Control-Allow-Methods': 'POST,GET,OPTIONS'
};

exports.handler = async (event) => {
  // Handle OPTIONS preflight request
  if (event.requestContext?.httpMethod === 'OPTIONS' || event.httpMethod === 'OPTIONS') {
    return {
      statusCode: 200,
      headers: {
        'Content-Type': 'application/json',
        ...corsHeaders
      },
      body: JSON.stringify({})
    };
  }

  try {
    logger.info('Booking Lambda invoked', { event });

    const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    const { eventId, quantity, userEmail } = body;

    if (!eventId || !quantity || !userEmail) {
      return {
        statusCode: 400,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Headers': 'Content-Type',
          'Access-Control-Allow-Methods': 'POST,GET,OPTIONS'
        },
        body: JSON.stringify({ error: 'Missing required fields: eventId, quantity, userEmail' }),
      };
    }

    const userId = 'user-123';
    const bookingId = `BOOK-${Date.now()}-${uuidv4().substr(0, 8)}`;
    const createdAt = new Date().toISOString();

    logger.info('Fetching event details from DynamoDB', { eventId });

    const eventResponse = await dynamodb.get({
      TableName: process.env.EVENTS_TABLE || 'Events',
      Key: { eventId },
    }).promise();

    const eventItem = eventResponse.Item || {};
    const eventName = eventItem.name || 'Unknown Event';
    const eventDate = eventItem.date || '';
    const ticketPrice = parseFloat(eventItem.ticketPrice || '0');
    const totalPrice = quantity * ticketPrice;

    logger.info('Creating booking in DynamoDB', { bookingId, eventId, quantity });

    await dynamodb.put({
      TableName: process.env.BOOKINGS_TABLE || 'Bookings',
      Item: {
        userId,
        bookingId,
        eventId,
        quantity,
        totalPrice,
        status: BOOKING_STATUS.PENDING,
        userEmail,
        createdAt,
      },
    }).promise();

    logger.info('Sending booking to SQS for ticket generation', { bookingId });

    await sqs.sendMessage({
      QueueUrl: process.env.BOOKING_QUEUE_URL,
      MessageBody: JSON.stringify({
        bookingId,
        userId,
        eventId,
        eventName,
        eventDate,
        quantity,
        totalPrice,
        userEmail,
        createdAt,
      }),
    }).promise();

    logger.info('Booking created successfully', { bookingId, totalPrice });

    return {
      statusCode: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type',
        'Access-Control-Allow-Methods': 'POST,GET,OPTIONS'
      },
      body: JSON.stringify({
        success: true,
        bookingId,
        totalPrice,
        status: BOOKING_STATUS.PENDING,
      }),
    };
  } catch (error) {
    logger.error('Error in booking Lambda', error);
    return {
      statusCode: 500,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type',
        'Access-Control-Allow-Methods': 'POST,GET,OPTIONS'
      },
      body: JSON.stringify({ error: error.message }),
    };
  }
};
