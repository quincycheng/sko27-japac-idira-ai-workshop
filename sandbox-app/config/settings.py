"""Application settings for the incident summariser."""

# --- Bedrock ---------------------------------------------------------------
AWS_REGION = "us-east-1"
MODEL_ID = "us.anthropic.claude-sonnet-4-5-20250929-v1:0"

# --- AWS credentials -------------------------------------------------------
# TODO: move these somewhere safer before we ship this
AWS_ACCESS_KEY_ID = "AKIAIOSFODNN7EXAMPLE"
AWS_SECRET_ACCESS_KEY = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
