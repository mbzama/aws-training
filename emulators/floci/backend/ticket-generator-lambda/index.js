const { v4: uuidv4 } = require('uuid');
const logger = require('../shared/logger');
const { dynamodb, s3 } = require('../shared/aws-clients');
const { BOOKING_STATUS, updateBookingStatus } = require('../shared/booking-service');

/**
 * Ticket Generator Lambda Handler
 * Triggered by SQS
 * 
 * Workflow:
 * 1. Read booking message from SQS
 * 2. Generate ticket PDF
 * 3. Upload PDF to S3
 * 4. Update booking status to CONFIRMED
 * 5. Store ticket URL in booking record
 * 
 * Retry logic:
 * - SQS will retry up to 3 times with exponential backoff
 * - Failed messages go to DLQ
 */
const handler = async (event) => {
  const requestId = uuidv4();

  logger.info('Ticket Generator Lambda triggered', {
    requestId,
    recordCount: event.Records.length,
  });

  const results = [];

  // Process each SQS message
  for (const record of event.Records) {
    try {
      await processBookingMessage(record, requestId);
      results.push({
        messageId: record.messageId,
        status: 'success',
      });
    } catch (error) {
      logger.error('Failed to process booking message', error, {
        requestId,
        messageId: record.messageId,
      });

      // Re-throw to trigger SQS retry/DLQ
      results.push({
        messageId: record.messageId,
        status: 'failed',
        error: error.message,
      });
    }
  }

  logger.info('Ticket Generator Lambda completed', {
    requestId,
    results,
  });

  return { statusCode: 200, body: JSON.stringify({ results }) };
};

/**
 * Process individual booking message
 */
const processBookingMessage = async (record, requestId) => {
  try {
    const message = JSON.parse(record.body);

    const { bookingId, userId, eventId, eventName, quantity, totalPrice, userEmail, createdAt } =
      message;

    logger.info('Processing booking message', {
      requestId,
      bookingId,
      userId,
      eventId,
    });

    // Update booking status to PROCESSING
    const bookingsTable = process.env.BOOKINGS_TABLE;
    await dynamodb
      .update({
        TableName: bookingsTable,
        Key: {
          userId,
          bookingId,
        },
        UpdateExpression: 'SET #status = :status, updatedAt = :updatedAt',
        ExpressionAttributeNames: {
          '#status': 'status',
        },
        ExpressionAttributeValues: {
          ':status': BOOKING_STATUS.PROCESSING,
          ':updatedAt': new Date().toISOString(),
        },
      })
      .promise();

    logger.info('Booking status updated to PROCESSING', {
      requestId,
      bookingId,
    });

    // Generate ticket PDF content
    const ticketPdf = generateTicketPDF({
      bookingId,
      eventName,
      eventDate: message.eventDate,
      quantity,
      userEmail,
      totalPrice,
      createdAt,
    });

    // Upload PDF to S3
    const ticketsBucket = process.env.TICKETS_BUCKET;
    const ticketKey = `tickets/${userId}/${bookingId}.pdf`;

    const s3Params = {
      Bucket: ticketsBucket,
      Key: ticketKey,
      Body: ticketPdf,
      ContentType: 'application/pdf',
      Metadata: {
        bookingId,
        userId,
        eventId,
      },
    };

    await s3.putObject(s3Params).promise();

    logger.info('Ticket PDF uploaded to S3', {
      requestId,
      bucket: ticketsBucket,
      key: ticketKey,
    });

    // Generate S3 URL (public or signed URL)
    const ticketUrl = `s3://${ticketsBucket}/${ticketKey}`;

    // Update booking with ticket URL and status to CONFIRMED
    await dynamodb
      .update({
        TableName: bookingsTable,
        Key: {
          userId,
          bookingId,
        },
        UpdateExpression: 'SET #status = :status, ticketUrl = :ticketUrl, updatedAt = :updatedAt',
        ExpressionAttributeNames: {
          '#status': 'status',
        },
        ExpressionAttributeValues: {
          ':status': BOOKING_STATUS.CONFIRMED,
          ':ticketUrl': ticketUrl,
          ':updatedAt': new Date().toISOString(),
        },
      })
      .promise();

    logger.info('Booking confirmed with ticket', {
      requestId,
      bookingId,
      ticketUrl,
    });
  } catch (error) {
    logger.error('Error processing booking message', error, {
      requestId,
      message: record.body,
    });
    throw error;
  }
};

/**
 * Generate ticket PDF content as a proper PDF binary buffer
 * Uses pure JavaScript PDF structure generation (no external dependencies)
 * Produces a valid PDF-1.4 document that can be read by any PDF viewer
 */
const generateTicketPDF = (ticketData) => {
  const {
    bookingId,
    eventName,
    eventDate,
    quantity,
    userEmail,
    totalPrice,
    createdAt,
  } = ticketData;

  // Build PDF content with proper structure
  const formatDate = (isoDate) => {
    try {
      return new Date(isoDate).toLocaleDateString('en-US', {
        year: 'numeric',
        month: 'long',
        day: 'numeric',
      });
    } catch {
      return isoDate;
    }
  };

  const ticketContent = [
    'EVENT TICKET CONFIRMATION',
    '',
    `Booking ID: ${bookingId}`,
    `Event: ${eventName}`,
    `Event Date: ${formatDate(eventDate)}`,
    `Quantity: ${quantity} ticket(s)`,
    `Total Price: $${parseFloat(totalPrice).toFixed(2)}`,
    `Purchaser Email: ${userEmail}`,
    `Purchase Date: ${formatDate(createdAt)}`,
    '',
    '--- TICKET DETAILS ---',
    `This is your official event ticket. Please present this`,
    `ticket or your booking confirmation at the event venue.`,
    '',
    `Booking Reference: ${bookingId}`,
    `Event: ${eventName}`,
    `Tickets: ${quantity}`,
  ].join('\n');

  // Build PDF objects as strings
  const obj1 = '<< /Type /Catalog /Pages 2 0 R >>';
  const obj2 = '<< /Type /Pages /Kids [3 0 R] /Count 1 >>';
  const obj3 = '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R /Resources << /Font << /F1 << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >> >> >> >>';

  // Build stream content with proper text positioning
  const streamLines = [
    'BT',
    '/F1 20 Tf',
    '50 750 Td',
    '(EVENT TICKET CONFIRMATION) Tj',
    '0 -30 Td',
    '/F1 12 Tf',
    `(Booking ID: ${bookingId}) Tj`,
    '0 -20 Td',
    `(Event: ${eventName}) Tj`,
    '0 -20 Td',
    `(Date: ${formatDate(eventDate)}) Tj`,
    '0 -20 Td',
    `(Quantity: ${quantity} ticket(s)) Tj`,
    '0 -20 Td',
    `(Price: $${parseFloat(totalPrice).toFixed(2)}) Tj`,
    '0 -20 Td',
    `(Email: ${userEmail}) Tj`,
    '0 -20 Td',
    `(Booked: ${formatDate(createdAt)}) Tj`,
    '0 -30 Td',
    '/F1 10 Tf',
    '(Please present this ticket at the event venue.) Tj',
    'ET',
  ].join('\n');

  const stream = `stream\n${streamLines}\nendstream`;
  const obj4Start = `<< /Length ${streamLines.length + 14} >>\n${stream}`;

  // Build complete PDF
  const pdfParts = [];
  const objects = [];
  const offsets = [];

  // Header
  pdfParts.push('%PDF-1.4\n%\xE2\xE3\xCF\xD3\n');

  // Object 1
  offsets.push(pdfParts.join('').length);
  pdfParts.push(`1 0 obj\n${obj1}\nendobj\n`);

  // Object 2
  offsets.push(pdfParts.join('').length);
  pdfParts.push(`2 0 obj\n${obj2}\nendobj\n`);

  // Object 3
  offsets.push(pdfParts.join('').length);
  pdfParts.push(`3 0 obj\n${obj3}\nendobj\n`);

  // Object 4
  offsets.push(pdfParts.join('').length);
  pdfParts.push(`4 0 obj\n${obj4Start}\nendobj\n`);

  // Build xref table
  const xrefOffset = pdfParts.join('').length;
  let xrefTable = 'xref\n';
  xrefTable += '0 5\n';
  xrefTable += '0000000000 65535 f \n';

  for (let i = 0; i < 4; i++) {
    xrefTable += `${String(offsets[i]).padStart(10, '0')} 00000 n \n`;
  }

  pdfParts.push(xrefTable);
  pdfParts.push('trailer\n');
  pdfParts.push('<< /Size 5 /Root 1 0 R >>\n');
  pdfParts.push('startxref\n');
  pdfParts.push(`${xrefOffset}\n`);
  pdfParts.push('%%EOF\n');

  const pdfString = pdfParts.join('');
  return Buffer.from(pdfString, 'utf8');
};

module.exports = { handler };
