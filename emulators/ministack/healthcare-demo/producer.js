const AWS = require('aws-sdk');

const endpoint = 'http://localhost:4566';
const region = 'us-east-1';

const kinesis = new AWS.Kinesis({ endpoint, region });
const dynamodb = new AWS.DynamoDB.DocumentClient({ endpoint, region });
const sns = new AWS.SNS({ endpoint, region });

exports.handler = async (event) => {
  // Handle both API Gateway and direct Lambda invocation
  const appointment = event.body 
    ? (typeof event.body === 'string' ? JSON.parse(event.body) : event.body)
    : event;

  const appointmentId = 'APT-' + Date.now();

  await dynamodb.put({
    TableName: 'patient-appointments',
    Item: {
      appointmentId,
      patientId: appointment.patientId || 'P-' + Date.now(),
      patientName: appointment.patientName,
      doctor: appointment.doctor,
      department: appointment.department,
      status: appointment.status || 'BOOKED',
      createdAt: new Date().toISOString()
    }
  }).promise();

  await kinesis.putRecord({
    StreamName: 'patient-events',
    PartitionKey: appointment.patientId || 'default',
    Data: JSON.stringify({ ...appointment, appointmentId })
  }).promise();

  await sns.publish({
    TopicArn: 'arn:aws:sns:us-east-1:000000000000:patient-notifications',
    Message: JSON.stringify({ appointmentId, patientName: appointment.patientName, doctor: appointment.doctor, status: 'BOOKED' }),
    Subject: 'New Appointment Booked'
  }).promise();

  return {
    statusCode: 200,
    body: JSON.stringify({ message: 'Appointment booked!', appointmentId })
  };
};
