import boto3                                                                                           
import json                                                                                            
                                                                                                         
client = boto3.client("lambda", region_name="us-east-1")
                                                                                                         
FUNCTION_NAME = "create-ips"
INVOCATION_COUNT = 120


def invoke_lambda(i):
      response = client.invoke(
          FunctionName=FUNCTION_NAME,
          InvocationType="RequestResponse",
          Payload=json.dumps({"trigger_id": i}).encode(),
      )
      result = json.loads(response["Payload"].read())
      print(f"[{i}] status={response['StatusCode']} result={result}")
      return result


def lambda_handler(event, context):
      success, failed = 0, 0

      for i in range(INVOCATION_COUNT):
          try:
              result = invoke_lambda(i)
              if result.get("statusCode") == 200:
                  success += 1
              else:
                  failed += 1
          except Exception as e:
              print(f"[{i}] Exception -> {e}")
              failed += 1

      print(f"Done — success: {success}, failed: {failed}")
      return {
          "statusCode": 200,
          "body": json.dumps({"triggered": INVOCATION_COUNT, "success": success, "failed": failed}),
      }