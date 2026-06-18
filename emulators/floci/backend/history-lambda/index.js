const logger = require('../shared/logger');
const { dynamodb } = require('../shared/aws-clients');

const corsHeaders = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type',
  'Access-Control-Allow-Methods': 'GET,OPTIONS'
};

exports.handler = async (event) => {
  // Handle OPTIONS preflight request
  if (event.requestContext?.httpMethod === 'OPTIONS' || event.httpMethod === 'OPTIONS') {
    return {
      statusCode: 200,
      headers: corsHeaders,
      body: JSON.stringify({})
    };
  }

  try {
    logger.info('History Lambda invoked');

    const userId = 'user-123';
    const tableName = process.env.BOOKINGS_TABLE || 'Bookings';

    const result = await dynamodb.query({
      TableName: tableName,
      KeyConditionExpression: 'userId = :userId',
      ExpressionAttributeValues: { ':userId': userId }
    }).promise();

    logger.info('Booking history retrieved', { userId, count: result.Items?.length || 0 });

    return {
      statusCode: 200,
      headers: corsHeaders,
      body: JSON.stringify({ bookings: result.Items || [] })
    };
  } catch (error) {
    logger.error('Error in history Lambda', error);
    return {
      statusCode: 500,
      headers: corsHeaders,
      body: JSON.stringify({ error: error.message })
    };
  }
};
