#!/usr/bin/env sh
# Lambda 関数作成/更新（冪等）
set -eu
. "$(dirname "$0")/00_env.sh"
ROLE_ARN="$(cat .role_arn)"
ZIP=.build/lambda.zip
mkdir -p .build

# パッケージ作成（books_handler.py をzipのルートに配置）
rm -f "$ZIP" || true
zip -j "$ZIP" src/lambda/books_handler.py >/dev/null

if aws lambda get-function --function-name "$FUNCTION_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
  echo "[INFO] Updating lambda code..."
  aws lambda update-function-code --function-name "$FUNCTION_NAME" --zip-file fileb://"$ZIP" --region "$AWS_REGION" >/dev/null
  aws lambda update-function-configuration \
    --function-name "$FUNCTION_NAME" \
    --runtime python3.11 \
    --role "$ROLE_ARN" \
    --handler books_handler.lambda_handler \
    --environment "Variables={TABLE_NAME=$TABLE_NAME}" \
    --timeout 10 --memory-size 256 \
    --region "$AWS_REGION" >/dev/null
else
  echo "[INFO] Creating lambda function..."
  aws lambda create-function \
    --function-name "$FUNCTION_NAME" \
    --runtime python3.11 \
    --role "$ROLE_ARN" \
    --handler books_handler.lambda_handler \
    --zip-file fileb://"$ZIP" \
    --environment "Variables={TABLE_NAME=$TABLE_NAME}" \
    --timeout 10 --memory-size 256 \
    --region "$AWS_REGION"
fi
