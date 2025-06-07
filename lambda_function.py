import json

def lambda_handler(event, context):
    print("Event received:", json.dumps(event))

    # API Gateway v2 (HTTP API) — use presence of 'requestContext'
    if "requestContext" in event and "http" in event["requestContext"]:
        return {
            "statusCode": 200,
            "body": json.dumps("API Gateway call successful!")
        }

    # S3 trigger
    if "Records" in event and event["Records"][0].get("eventSource") == "aws:s3":
        s3 = event["Records"][0]["s3"]
        bucket = s3["bucket"]["name"]
        key = s3["object"]["key"]
        print(f"File uploaded to s3://{bucket}/{key}")
        return {
            "statusCode": 200,
            "body": json.dumps(f"Processed file: s3://{bucket}/{key}")
        }

    # Fallback
    return {
        "statusCode": 400,
        "body": json.dumps("Unknown event source")
    }
