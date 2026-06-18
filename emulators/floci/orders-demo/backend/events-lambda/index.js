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
    logger.info('Events Lambda invoked');

    const tableName = process.env.EVENTS_TABLE || 'Events';
    const result = await dynamodb.scan({ TableName: tableName }).promise();

    logger.info('Events retrieved successfully', { count: result.Items?.length || 0 });

    return {
      statusCode: 200,
      headers: corsHeaders,
      body: JSON.stringify({ events: result.Items || [] })
    };
  } catch (error) {
    logger.error('Error in events Lambda', error);
    return {
      statusCode: 500,
      headers: corsHeaders,
      body: JSON.stringify({ error: error.message })
    };
  }
};
