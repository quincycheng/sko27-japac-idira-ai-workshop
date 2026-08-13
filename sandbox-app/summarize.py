"""Summarise a security incident report using Amazon Bedrock.

Usage:
    python summarize.py [path-to-report.txt]
"""

import sys
from pathlib import Path

import boto3
from botocore.exceptions import ClientError, NoCredentialsError

from config.settings import (
    AWS_ACCESS_KEY_ID,
    AWS_REGION,
    AWS_SECRET_ACCESS_KEY,
    MODEL_ID,
)

PROMPT = (
    "Summarise this security incident report in three bullet points, "
    "then state the single most urgent action to take.\n\n{body}"
)


def build_client():
    """Create a Bedrock client using the credentials from config/settings.py."""
    return boto3.client(
        "bedrock-runtime",
        region_name=AWS_REGION,
        aws_access_key_id=AWS_ACCESS_KEY_ID,
        aws_secret_access_key=AWS_SECRET_ACCESS_KEY,
    )


def summarise(text):
    response = build_client().converse(
        modelId=MODEL_ID,
        messages=[{"role": "user", "content": [{"text": PROMPT.format(body=text)}]}],
        inferenceConfig={"maxTokens": 512, "temperature": 0},
    )
    return response["output"]["message"]["content"][0]["text"]


def main():
    path = Path(sys.argv[1] if len(sys.argv) > 1 else "sample-incident.txt")
    if not path.exists():
        sys.exit(f"No such file: {path}")

    try:
        print(summarise(path.read_text(encoding="utf-8")))
    except (ClientError, NoCredentialsError) as error:
        print("", file=sys.stderr)
        print(f"Bedrock rejected the request: {error}", file=sys.stderr)
        print("", file=sys.stderr)
        print(
            "The AWS credentials this app is using are not valid.\n"
            "Look at config/settings.py to see where they come from.",
            file=sys.stderr,
        )
        raise SystemExit(1)


if __name__ == "__main__":
    main()
