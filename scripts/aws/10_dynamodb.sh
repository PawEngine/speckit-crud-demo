#!/usr/bin/env sh
# DynamoDB テーブル作成（冪等）
set -eu
. "$(dirname "$0")/00_env.sh"

# 既存チェック
if aws dynamodb describe-table --table-name "$TABLE_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
  echo "[INFO] DynamoDB table '$TABLE_NAME' already exists. Skipping create."
else
  echo "[INFO] Creating DynamoDB table '$TABLE_NAME'..."
  aws dynamodb create-table \
    --table-name "$TABLE_NAME" \
    --attribute-definitions AttributeName=BookId,AttributeType=S \
    --key-schema AttributeName=BookId,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "$AWS_REGION"
  aws dynamodb wait table-exists --table-name "$TABLE_NAME" --region "$AWS_REGION"
  echo "[OK] Table created."
fi
