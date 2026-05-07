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


def list_poc_enis():
    resp = ec2.describe_network_interfaces(
        Filters=[
            {"Name": "subnet-id", "Values": [SUBNET_ID]},
            {"Name": "tag:Project", "Values": [POC_TAG_VALUE]},
        ]
    )
    return resp["NetworkInterfaces"]


def lambda_handler(event, context):
    enis = list_poc_enis()
    deleted, errors = [], []

    for eni in enis:
        eni_id = eni["NetworkInterfaceId"]
        try:
            ec2.delete_network_interface(NetworkInterfaceId=eni_id)
            deleted.append(eni_id)
            logger.info(f"Deleted ENI: {eni_id}")
        except ClientError as e:
            logger.error(f"Failed to delete {eni_id}: {e}")
            errors.append({"eni_id": eni_id, "error": str(e)})

    return {
        "statusCode": 200,
        "body": json.dumps({
            "status": "DONE",
            "deleted_count": len(deleted),
            "deleted": deleted,
            "errors": errors,
        }),
    }