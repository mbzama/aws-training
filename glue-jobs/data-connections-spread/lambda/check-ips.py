import json
import os
import boto3
import logging

SUBNET_ID = os.environ["SUBNET_ID"]

ec2 = boto3.client("ec2")
logger = logging.getLogger()
logger.setLevel(logging.INFO)


def identify_service(eni):
      interface_type = eni.get("InterfaceType", "")
      description    = eni.get("Description", "")
      requester_id   = eni.get("RequesterId", "")
      attachment     = eni.get("Attachment", {})
      instance_id    = attachment.get("InstanceId")
      instance_owner = attachment.get("InstanceOwnerId", "")
      desc           = description.lower()
      req            = requester_id.lower()

      # EC2 instance
      if instance_id:
          return f"EC2 ({instance_id})"

      # InterfaceType — most reliable signal
      type_map = {
          "nat_gateway":               "NAT Gateway",
          "network_load_balancer":     "Network Load Balancer",
          "load_balancer":             "Application Load Balancer",
          "lambda":                    "Lambda",
          "vpc_endpoint":              "VPC Endpoint",
          "transit_gateway":           "Transit Gateway",
          "api_gateway_managed":       "API Gateway",
          "global_accelerator_managed":"Global Accelerator",
          "efa":                       "Elastic Fabric Adapter",
          "trunk":                     "ECS Trunk ENI",
      }
      if interface_type in type_map:
          return type_map[interface_type]

      # Description-based
      if "rdsnetworkinterface" in desc or "rds" in desc:         return "RDS"
      if "aws lambda" in desc:                                    return "Lambda"
      if "elb" in desc or "elasticloadbalancing" in desc:        return "Elastic Load Balancer"
      if "nat gateway" in desc or "interface for nat" in desc:   return "NAT Gateway"
      if "elasticache" in desc:                                   return "ElastiCache"
      if "elasticmapreduce" in desc or "emr" in desc:            return "EMR"
      if "fargate" in desc:                                       return "ECS Fargate"
      if "ecs" in desc:                                           return "ECS"
      if "amazon eks" in desc or "eks" in desc:                  return "EKS"
      if "redshift" in desc:                                      return "Redshift"
      if "opensearch" in desc or "amazon es" in desc:            return "OpenSearch"
      if "sagemaker" in desc:                                     return "SageMaker"
      if "codebuild" in desc:                                     return "CodeBuild"
      if "dax" in desc:                                           return "DynamoDB DAX"
      if "msk" in desc or "kafka" in desc:                        return "MSK (Kafka)"
      if "workspaces" in desc:                                    return "WorkSpaces"
      if "directory" in desc:                                     return "Directory Service"
      if "cloudhsm" in desc:                                      return "CloudHSM"
      if "globalaccelerator" in desc:                             return "Global Accelerator"
      if "vpce" in desc or "vpc endpoint" in desc:               return "VPC Endpoint"
      if "transit gateway" in desc:                               return "Transit Gateway"

      # RequesterId-based
      if "amazon-elb"           in req: return "Elastic Load Balancer"
      if "amazon-rds"           in req: return "RDS"
      if "aws-lambda"           in req: return "Lambda"
      if "amazon-redshift"      in req: return "Redshift"
      if "amazon-elasticsearch" in req: return "OpenSearch"
      if "amazon-eks"           in req: return "EKS"
      if "amazon-ecs"           in req: return "ECS"
      if "amazon-sagemaker"     in req: return "SageMaker"

      # InstanceOwnerId-based
      if "amazon-elb" in instance_owner.lower():
          return "Elastic Load Balancer"

      # Last resort — show raw description or interface type so nothing is hidden
      if description:
          return f"{description[:60]}"
      return f"Interface type: {interface_type or 'untagged'}"


def lambda_handler(event, context):
      subnet_resp  = ec2.describe_subnets(SubnetIds=[SUBNET_ID])
      available_ips = subnet_resp["Subnets"][0]["AvailableIpAddressCount"]

      eni_resp = ec2.describe_network_interfaces(
          Filters=[{"Name": "subnet-id", "Values": [SUBNET_ID]}]
      )

      occupied = []
      for eni in eni_resp["NetworkInterfaces"]:
          service = identify_service(eni)
          for ip_entry in eni.get("PrivateIpAddresses", []):
              occupied.append({
                  "ip":      ip_entry["PrivateIpAddress"],
                  "primary": ip_entry["Primary"],
                  "eni_id":  eni["NetworkInterfaceId"],
                  "service": service,
                  "status":  eni.get("Status"),
              })

      occupied.sort(key=lambda x: x["ip"])

      logger.info(f"Subnet {SUBNET_ID} — available: {available_ips}, assigned: {len(occupied)}")

      return {
          "statusCode": 200,
          "body": json.dumps({
              "subnet_id":    SUBNET_ID,
              "available_ips": available_ips,
              "assigned_ips": len(occupied),
              "assigned":     occupied,
          }),
      }