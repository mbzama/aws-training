const AWS = require('aws-sdk');

const endpoint = 'http://localhost:4566';
const region = 'us-east-1';

const dynamodb = new AWS.DynamoDB.DocumentClient({ endpoint, region });
const sns = new AWS.SNS({ endpoint, region });
const s3 = new AWS.S3({ endpoint, region, s3ForcePathStyle: true });

exports.handler = async (event) => {
  console.log('Consumer triggered with', event.Records.length, 'records');

  for (const record of event.Records) {
    const payload = Buffer.from(record.kinesis.data, 'base64').toString('utf-8');
    const appointment = JSON.parse(payload);
    const appointmentId = appointment.appointmentId || ('APT-' + Date.now());

    console.log('Processing:', appointmentId);

    // 1. Update DynamoDB status to CONFIRMED
    await dynamodb.update({
      TableName: 'patient-appointments',
      Key: { appointmentId },
      UpdateExpression: 'SET #s = :status, processedAt = :time',
      ExpressionAttributeNames: { '#s': 'status' },
      ExpressionAttributeValues: {
        ':status': 'CONFIRMED',
        ':time': new Date().toISOString()
      }
    }).promise();
    console.log('✓ DynamoDB - status updated to CONFIRMED');

    // 2. Save record to S3
    await s3.putObject({
      Bucket: 'healthcare-records',
      Key: 'appointments/' + appointmentId + '.json',
      Body: JSON.stringify({
        appointmentId,
        patientId: appointment.patientId,
        patientName: appointment.patientName,
        doctor: appointment.doctor,
        department: appointment.department,
        status: 'CONFIRMED',
        confirmedAt: new Date().toISOString()
      }),
      ContentType: 'application/json'
    }).promise();
    console.log('✓ S3 - record saved to healthcare-records/appointments/');

    // 3. Send confirmation via SNS
    await sns.publish({
      TopicArn: 'arn:aws:sns:us-east-1:000000000000:patient-notifications',
      Message: JSON.stringify({
        type: 'APPOINTMENT_CONFIRMED',
        appointmentId,
        patientName: appointment.patientName,
        doctor: appointment.doctor,
        department: appointment.department
      }),
      Subject: 'Appointment Confirmed'
    }).promise();
    console.log('✓ SNS - confirmation published');
  }

  return { statusCode: 200, body: 'Processed ' + event.Records.length + ' records' };
};
