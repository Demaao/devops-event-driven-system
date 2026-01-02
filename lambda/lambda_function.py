import json
import boto3
import urllib3
import os

s3 = boto3.client("s3")
http = urllib3.PoolManager()

def lambda_handler(event, context):
    PRODUCER_SERVICE_URL = os.environ.get("PRODUCER_SERVICE_URL")
    if not PRODUCER_SERVICE_URL:
        raise Exception("PRODUCER_SERVICE_URL is not set")

    record = event["Records"][0]
    bucket = record["s3"]["bucket"]["name"]
    key = record["s3"]["object"]["key"].lower()

    if "product" in key:
        entity_type = "product"
    elif "order" in key:
        entity_type = "order"
    elif "supplier" in key:
        entity_type = "supplier"
    else:
        print("Unknown file type:", key)
        return {"statusCode": 400, "body": "Unknown file type"}

    obj = s3.get_object(Bucket=bucket, Key=key)
    items = json.loads(obj["Body"].read().decode("utf-8"))

    for item in items:
        payload = {
            "type": entity_type,
            "data": item
        }

        print("Sending payload:", payload)
        print("POST to:", PRODUCER_SERVICE_URL)

        response = http.request(
            "POST",
            PRODUCER_SERVICE_URL,
            body=json.dumps(payload),
            headers={"Content-Type": "application/json"}
        )

        print("Response status:", response.status)
        print("Response body:", response.data.decode("utf-8"))

    return {
        "statusCode": 200,
        "body": f"{len(items)} events sent to Kafka"
    }
