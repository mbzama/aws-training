import json                                             
import os
import boto3                                                                                           
import logging
from botocore.exceptions import ClientError                                                            
                       
SUBNET_ID = os.environ["SUBNET_ID"]
POC_TAG_VALUE = os.environ.get("POC_TAG_VALUE", "subnet-exhaustion-test")

ec2 = boto3.client("ec2")
logger = logging.getLogger()
logger.setLevel(logging.INFO)


def create_eni():
      resp = ec2.create_network_interface(
          SubnetId=SUBNET_ID,
          Description="POC subnet exhaustion test ENI",
          TagSpecifications=[{
              "ResourceType": "network-interface",
              "Tags": [
                  {"Key": "Project", "Value": POC_TAG_VALUE},
                  {"Key": "CreatedBy", "Value": "lambda"},
              ],
          }],
      )
      eni_id = resp["NetworkInterface"]["NetworkInterfaceId"]
      logger.info(f"Created ENI: {eni_id}")
      return eni_id


def available_ip_count():
      resp = ec2.describe_subnets(SubnetIds=[SUBNET_ID])
      return resp["Subnets"][0]["AvailableIpAddressCount"]


def lambda_handler(event, context):
      try:
          eni_id = create_eni()
          return {
              "statusCode": 200,
              "body": json.dumps({
                  "status": "CREATED",
                  "eni_id": eni_id,
                  "remaining_ips": available_ip_count(),
              }),
          }
      except ClientError as e:
          error_code = e.response["Error"]["Code"]
          logger.error(f"Failed to create ENI: {error_code} - {e}")
          return {
              "statusCode": 500,
              "body": json.dumps({
                  "status": "FAILED",
                  "error": error_code,
                  "message": str(e),
              }),
          }