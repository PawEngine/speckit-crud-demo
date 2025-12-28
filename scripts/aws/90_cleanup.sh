#!/usr/bin/env sh
# リソースのクリーンアップ（冪等）
set -eu
. "$(dirname "$0")/00_env.sh"

# API Gateway
if [ -f .api_id ]; then
  API_ID=$(cat .api_id)
else
  if [ -f .api_base_url ]; then
    API_ID=$(cut -d/ -f3 .api_base_url | cut -d. -f1)
  else
    API_ID=""
  fi
fi
if [ -n "${API_ID:-}" ] && [ "$API_ID" != "None" ]; then
  echo "[INFO] Deleting API Gateway: $API_ID"
  aws apigateway delete-rest-api --rest-api-id "$API_ID" --region "$AWS_REGION" || true
fi

# Lambda
aws lambda delete-function --function-name "$FUNCTION_NAME" --region "$AWS_REGION" || true

# IAM
POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/BooksApiDynamoDBPolicy"
aws iam detach-role-policy --role-name BooksApiRole --policy-arn "$POLICY_ARN" || true
aws iam delete-policy --policy-arn "$POLICY_ARN" || true
aws iam delete-role --role-name BooksApiRole || true

# DynamoDB
aws dynamodb delete-table --table-name "$TABLE_NAME" --region "$AWS_REGION" || true

# Local artifacts
rm -f .role_arn .api_id .api_base_url || true
rm -rf .build || true

echo "[INFO] Cleanup completed"
