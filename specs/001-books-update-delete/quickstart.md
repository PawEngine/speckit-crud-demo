# Quickstart: Update/Delete for Books API

このガイドは既存の Create/Read スタックに対して、破壊的変更なく Update（PUT）/Delete（DELETE）を追加する具体手順です。

## 前提
- `scripts/aws/00_env.sh` を読み込んだシェル環境
- 既存の API が動作済み（`.api_base_url` に Base URL 保存済み）

```sh
# 事前に環境変数を読み込む
. scripts/aws/00_env.sh
```

## Step 1: Lambda ハンドラのコード拡張（books_handler.py）
- ルーティングに `PUT /books/{bookId}` と `DELETE /books/{bookId}` を追加
- 入力検証（status許容値、空文字不可）と存在確認（404）

変更ファイル:
- `src/lambda/books_handler.py`

## Step 2: Lambda コードのデプロイ（更新）

```sh
# コードを zip 化（books_handler.py を zip 直下へ）
mkdir -p .build
cp src/lambda/books_handler.py .build/
(cd .build && zip -q books_handler.zip books_handler.py)

# Lambda 関数コードを更新
aws lambda update-function-code \
  --function-name "$FUNCTION_NAME" \
  --zip-file fileb://.build/books_handler.zip \
  --region "$AWS_REGION"

# 反映完了まで待機（任意）
aws lambda wait function-updated --function-name "$FUNCTION_NAME" --region "$AWS_REGION"
```

## Step 3: API Gateway の設定拡張（PUT/DELETE 追加）

```sh
# 既存 API とリソースIDの特定
API_ID=$(aws apigateway get-rest-apis --region "$AWS_REGION" --query "items[?name=='$API_NAME'].id | [0]" --output text)
BOOK_ID_RES=$(aws apigateway get-resources --rest-api-id "$API_ID" --region "$AWS_REGION" --query "items[?path=='/books/{bookId}'].id | [0]" --output text)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
LAMBDA_ARN="arn:aws:lambda:$AWS_REGION:$ACCOUNT_ID:function:$FUNCTION_NAME"
URI="arn:aws:apigateway:$AWS_REGION:lambda:path/2015-03-31/functions/$LAMBDA_ARN/invocations"

# メソッド作成（APIキー不要）
aws apigateway put-method --rest-api-id "$API_ID" --resource-id "$BOOK_ID_RES" --http-method PUT --authorization-type NONE --no-api-key-required --region "$AWS_REGION"
aws apigateway put-method --rest-api-id "$API_ID" --resource-id "$BOOK_ID_RES" --http-method DELETE --authorization-type NONE --no-api-key-required --region "$AWS_REGION"

# 統合（Lambda Proxy）
aws apigateway put-integration --rest-api-id "$API_ID" --resource-id "$BOOK_ID_RES" --http-method PUT --type AWS_PROXY --integration-http-method POST --uri "$URI" --region "$AWS_REGION"
aws apigateway put-integration --rest-api-id "$API_ID" --resource-id "$BOOK_ID_RES" --http-method DELETE --type AWS_PROXY --integration-http-method POST --uri "$URI" --region "$AWS_REGION"

# Lambda への権限付与（API Gateway からの呼び出しを許可）
aws lambda add-permission \
  --function-name "$FUNCTION_NAME" \
  --statement-id "apigw-put" \
  --action "lambda:InvokeFunction" \
  --principal apigateway.amazonaws.com \
  --source-arn "arn:aws:execute-api:$AWS_REGION:$ACCOUNT_ID:$API_ID/*/PUT/books/*" \
  --region "$AWS_REGION" || true
aws lambda add-permission \
  --function-name "$FUNCTION_NAME" \
  --statement-id "apigw-delete" \
  --action "lambda:InvokeFunction" \
  --principal apigateway.amazonaws.com \
  --source-arn "arn:aws:execute-api:$AWS_REGION:$ACCOUNT_ID:$API_ID/*/DELETE/books/*" \
  --region "$AWS_REGION" || true

# デプロイ
aws apigateway create-deployment --rest-api-id "$API_ID" --stage-name "$STAGE" --region "$AWS_REGION"
```

## 動作確認（curl）

```sh
API_BASE=$(cat .api_base_url)

# 作成
BOOK_ID=$(curl -s -X POST "$API_BASE/books" -H 'Content-Type: application/json' -d '{"title":"初期","author":"著者","status":"未読"}' | jq -r .bookId)

# 更新
curl -s -X PUT "$API_BASE/books/$BOOK_ID" -H 'Content-Type: application/json' -d '{"title":"改題","status":"読了"}' | jq .

# 削除
curl -s -X DELETE "$API_BASE/books/$BOOK_ID" | jq .

# 404 確認
curl -s -o /dev/null -w "%{http_code}\n" "$API_BASE/books/$BOOK_ID"
```

## ロールバック

```sh
# API Gateway メソッド削除（PUT/DELETE）
aws apigateway delete-method --rest-api-id "$API_ID" --resource-id "$BOOK_ID_RES" --http-method PUT --region "$AWS_REGION" || true
aws apigateway delete-method --rest-api-id "$API_ID" --resource-id "$BOOK_ID_RES" --http-method DELETE --region "$AWS_REGION" || true
aws apigateway create-deployment --rest-api-id "$API_ID" --stage-name "$STAGE" --region "$AWS_REGION"

# Lambda コードを元に戻す（例: 前バージョンzipを再デプロイ）
# ※ 実運用ではバージョン管理（publish-version）やS3配布を推奨
aws lambda update-function-code --function-name "$FUNCTION_NAME" --zip-file fileb://.build/books_handler_prev.zip --region "$AWS_REGION"
```

## 備考
- 既存の DynamoDB テーブル/IAM ロール/API Gateway を再利用します。
- 差分適用のみを行い、Create/Read の挙動には影響を与えません。
