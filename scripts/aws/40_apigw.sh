#!/usr/bin/env sh
# API Gateway (REST) 作成/更新（冪等）
set -eu
. "$(dirname "$0")/00_env.sh"

# API の存在確認
API_ID="$(aws apigateway get-rest-apis --region "$AWS_REGION" --query "items[?name=='$API_NAME'].id | [0]" --output text)"
if [ "$API_ID" = "None" ] || [ -z "$API_ID" ]; then
  echo "[INFO] Creating REST API..."
  API_ID="$(aws apigateway create-rest-api --name "$API_NAME" --region "$AWS_REGION" --query id --output text)"
else
  echo "[INFO] Using existing REST API: $API_ID"
fi

echo "$API_ID" > .api_id

# ルートリソース取得
ROOT_ID="$(aws apigateway get-resources --rest-api-id "$API_ID" --region "$AWS_REGION" --query "items[?path=='/'].id | [0]" --output text)"

# /books リソース作成（存在しなければ）
BOOKS_ID="$(aws apigateway get-resources --rest-api-id "$API_ID" --region "$AWS_REGION" --query "items[?path=='/books'].id | [0]" --output text)"
if [ "$BOOKS_ID" = "None" ] || [ -z "$BOOKS_ID" ]; then
  BOOKS_ID="$(aws apigateway create-resource --rest-api-id "$API_ID" --parent-id "$ROOT_ID" --path-part books --region "$AWS_REGION" --query id --output text)"
fi

# /books/{bookId} リソース作成（存在しなければ）
BOOK_ID_RES_ID="$(aws apigateway get-resources --rest-api-id "$API_ID" --region "$AWS_REGION" --query "items[?path=='/books/{bookId}'].id | [0]" --output text)"
if [ "$BOOK_ID_RES_ID" = "None" ] || [ -z "$BOOK_ID_RES_ID" ]; then
  BOOK_ID_RES_ID="$(aws apigateway create-resource --rest-api-id "$API_ID" --parent-id "$BOOKS_ID" --path-part "{bookId}" --region "$AWS_REGION" --query id --output text)"
fi

# Lambda ARN
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
LAMBDA_ARN="arn:aws:lambda:$AWS_REGION:$ACCOUNT_ID:function:$FUNCTION_NAME"

# Lambda 呼び出し権限（APIGW → Lambda）
aws lambda add-permission \
  --function-name "$FUNCTION_NAME" \
  --statement-id apigw-invoke-permission \
  --action lambda:InvokeFunction \
  --principal apigateway.amazonaws.com \
  --source-arn "arn:aws:execute-api:$AWS_REGION:$ACCOUNT_ID:*/*/*/*" \
  --region "$AWS_REGION" >/dev/null 2>&1 || true

create_or_put_method() {
  RES_ID=$1
  HTTP_METHOD=$2
  if aws apigateway get-method --rest-api-id "$API_ID" --resource-id "$RES_ID" --http-method "$HTTP_METHOD" --region "$AWS_REGION" >/dev/null 2>&1; then
    echo "[INFO] Method $HTTP_METHOD exists on $RES_ID"
  else
    aws apigateway put-method --rest-api-id "$API_ID" --resource-id "$RES_ID" --http-method "$HTTP_METHOD" --authorization-type "NONE" --no-api-key-required --region "$AWS_REGION" >/dev/null
  fi
  # 統合（Lambda プロキシ）
  aws apigateway put-integration \
    --rest-api-id "$API_ID" \
    --resource-id "$RES_ID" \
    --http-method "$HTTP_METHOD" \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri "arn:aws:apigateway:$AWS_REGION:lambda:path/2015-03-31/functions/$LAMBDA_ARN/invocations" \
    --region "$AWS_REGION" >/dev/null
}

# /books: POST, GET
create_or_put_method "$BOOKS_ID" POST
create_or_put_method "$BOOKS_ID" GET

# /books/{bookId}: GET
create_or_put_method "$BOOK_ID_RES_ID" GET

# デプロイ
STAGE_NAME="$STAGE"
aws apigateway create-deployment --rest-api-id "$API_ID" --stage-name "$STAGE_NAME" --region "$AWS_REGION" >/dev/null

BASE_URL="https://$API_ID.execute-api.$AWS_REGION.amazonaws.com/$STAGE_NAME"
echo "$BASE_URL" > .api_base_url

echo "[INFO] API Base URL: $BASE_URL"
