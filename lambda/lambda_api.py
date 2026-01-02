import json
import urllib3
import os

http = urllib3.PoolManager()

PRODUCER_SERVICE_URL = os.environ["PRODUCER_SERVICE_URL"]

TOPIC_MAP = {
    "product": "products",
    "order": "orders",
    "supplier": "suppliers"
}

def lambda_handler(event, context):
    body = json.loads(event["body"])
    entity_type = body.get("type")

    if entity_type not in TOPIC_MAP:
        return {
            "statusCode": 400,
            "body": "Invalid type"
        }

    payload = {
        "type": entity_type,
        "data": body.get("data", body)
    }

    r = http.request(
        "POST",
        PRODUCER_SERVICE_URL,
        body=json.dumps(payload),
        headers={"Content-Type": "application/json"}
    )

    return {
        "statusCode": r.status,
        "body": "Event forwarded"
    }
