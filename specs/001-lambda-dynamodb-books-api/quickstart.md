# Quickstart: Lambda+DynamoDB 書籍管理API（Create/Read）

この手順はAWS CLIのみで実行できます。実装前に実行し、動作をcurlで確認します。

## 前提
- AWS CLI v2
- 認証済みプロファイル（`aws sts get-caller-identity`で確認）

## 0. 環境変数
```sh
export AWS_REGION=ap-northeast-1
export STAGE=v1
export TABLE_NAME=BooksTable
export FUNCTION_NAME=BooksApiFunction
export API_NAME=BooksApi
export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
```

## 1. DynamoDB テーブル
```sh
aws dynamodb create-table \
  --table-name "$TABLE_NAME" \
  --attribute-definitions AttributeName=BookId,AttributeType=S \
  --key-schema AttributeName=BookId,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region "$AWS_REGION"
aws dynamodb wait table-exists --table-name "$TABLE_NAME" --region "$AWS_REGION"
```

## 2. IAM ロール/ポリシー
```sh
cat > lambda-trust-policy.json <<'JSON'
{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"lambda.amazonaws.com"},"Action":"sts:AssumeRole"}]}
JSON
cat > lambda-dynamodb-policy.json <<'JSON'
{"Version":"2012-10-17","Statement":[
 {"Effect":"Allow","Action":["dynamodb:PutItem","dynamodb:GetItem","dynamodb:Scan"],"Resource":"arn:aws:dynamodb:*:*:table/BooksTable"},
 {"Effect":"Allow","Action":["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"],"Resource":"*"}
]}
JSON
aws iam create-role --role-name BooksApiRole --assume-role-policy-document file://lambda-trust-policy.json
aws iam create-policy --policy-name BooksApiDynamoDBPolicy --policy-document file://lambda-dynamodb-policy.json
aws iam attach-role-policy --role-name BooksApiRole --policy-arn "arn:aws:iam::${ACCOUNT_ID}:policy/BooksApiDynamoDBPolicy"
ROLE_ARN=$(aws iam get-role --role-name BooksApiRole --query 'Role.Arn' --output text)
```

## 3. Lambda 関数
```sh
mkdir -p src/lambda
cat > src/lambda/books_handler.py <<'PY'
# 書籍管理APIハンドラ（日本語コメント）
# - POST /books: 書籍を登録（UUID発行）
# - GET /books/{bookId}: 1件取得
# - GET /books: 一覧取得（最大100件）
import json, os, uuid, boto3
from boto3.dynamodb.conditions import Key

ddb = boto3.resource('dynamodb')
TABLE = ddb.Table(os.environ['TABLE_NAME'])

ALLOWED_STATUS = {'未読','読了'}

def _response(status, body):
    return {
        'statusCode': status,
        'headers': {'Content-Type': 'application/json'},
        'body': json.dumps(body, ensure_ascii=False)
    }

def lambda_handler(event, _context):
    # ルーティング（Lambda Proxy）
    method = event.get('httpMethod')
    path = event.get('path', '')
    if method == 'POST' and path.endswith('/books'):
        body = json.loads(event.get('body') or '{}')
        title = (body.get('title') or '').strip()
        author = (body.get('author') or '').strip()
        status = body.get('status') or '未読'
        published = body.get('publishedDate')
        if not title:
            return _response(400, {'code':'VALIDATION_ERROR','message':'title is required'})
        if not author:
            return _response(400, {'code':'VALIDATION_ERROR','message':'author is required'})
        if status not in ALLOWED_STATUS:
            return _response(400, {'code':'VALIDATION_ERROR','message':'status must be 未読 or 読了'})
        book_id = str(uuid.uuid4())
        item = {'BookId': book_id, 'title': title, 'author': author, 'status': status}
        if published:
            item['publishedDate'] = published
        TABLE.put_item(Item=item)
        return _response(201, {'bookId': book_id})
    if method == 'GET' and '/books/' in path:
        book_id = path.rsplit('/', 1)[-1]
        res = TABLE.get_item(Key={'BookId': book_id})
        item = res.get('Item')
        if not item:
            return _response(404, {'code':'NOT_FOUND','message':'book not found'})
        # 表示用に整形
        out = {
            'bookId': item['BookId'],
            'title': item['title'],
            'author': item['author'],
            'status': item['status']
        }
        if 'publishedDate' in item:
            out['publishedDate'] = item['publishedDate']
        return _response(200, out)
    if method == 'GET' and path.endswith('/books'):
        limit = 100
        res = TABLE.scan(Limit=limit)
        items = [{
            'bookId': it['BookId'],
            'title': it['title'],
            'author': it['author'],
            'status': it['status'],
            **({'publishedDate': it['publishedDate']} if 'publishedDate' in it else {})
        } for it in res.get('Items', [])]
        body = {'items': items, 'count': len(items)}
        if 'LastEvaluatedKey' in res:
            body['lastEvaluatedKey'] = res['LastEvaluatedKey'].get('BookId')
        return _response(200, body)
    return _response(404, {'code':'NOT_FOUND','message':'route not found'})
PY

zip -r .build/lambda.zip src/lambda -x "*.pyc" "__pycache__/*"
aws lambda create-function \
  --function-name "$FUNCTION_NAME" \
  --runtime python3.11 \
  --role "$ROLE_ARN" \
  --handler lambda/books_handler.lambda_handler \
  --zip-file fileb://.build/lambda.zip \
  --environment Variables="TABLE_NAME=$TABLE_NAME" \
  --timeout 10 --memory-size 256 \
  --region "$AWS_REGION"
```

## 4. API Gateway (REST)
```sh
REST_ID=$(aws apigateway create-rest-api --name "$API_NAME" --region "$AWS_REGION" --query id --output text)
ROOT_ID=$(aws apigateway get-resources --rest-api-id "$REST_ID" --region "$AWS_REGION" --query 'items[?path==`/`].id' --output text)
BOOKS_ID=$(aws apigateway create-resource --rest-api-id "$REST_ID" --parent-id "$ROOT_ID" --path-part books --region "$AWS_REGION" --query id --output text)
BOOK_ID=$(aws apigateway create-resource --rest-api-id "$REST_ID" --parent-id "$BOOKS_ID" --path-part {bookId} --region "$AWS_REGION" --query id --output text)
aws apigateway put-method --rest-api-id "$REST_ID" --resource-id "$BOOKS_ID" --http-method POST --authorization-type NONE --region "$AWS_REGION"
aws apigateway put-method --rest-api-id "$REST_ID" --resource-id "$BOOK_ID"  --http-method GET  --authorization-type NONE --region "$AWS_REGION"
aws apigateway put-method --rest-api-id "$REST_ID" --resource-id "$BOOKS_ID" --http-method GET  --authorization-type NONE --region "$AWS_REGION"
LAMBDA_ARN="arn:aws:lambda:${AWS_REGION}:${ACCOUNT_ID}:function:${FUNCTION_NAME}"
URI="arn:aws:apigateway:${AWS_REGION}:lambda:path/2015-03-31/functions/${LAMBDA_ARN}/invocations"
aws apigateway put-integration --rest-api-id "$REST_ID" --resource-id "$BOOKS_ID" --http-method POST --type AWS_PROXY --integration-http-method POST --uri "$URI" --region "$AWS_REGION"
aws apigateway put-integration --rest-api-id "$REST_ID" --resource-id "$BOOK_ID"  --http-method GET  --type AWS_PROXY --integration-http-method POST --uri "$URI" --region "$AWS_REGION"
aws apigateway put-integration --rest-api-id "$REST_ID" --resource-id "$BOOKS_ID" --http-method GET  --type AWS_PROXY --integration-http-method POST --uri "$URI" --region "$AWS_REGION"
aws lambda add-permission --function-name "$FUNCTION_NAME" --statement-id apigw-invoke --action lambda:InvokeFunction --principal apigateway.amazonaws.com --source-arn "arn:aws:execute-api:${AWS_REGION}:${ACCOUNT_ID}:${REST_ID}/*/*/*"
aws apigateway create-deployment --rest-api-id "$REST_ID" --stage-name "$STAGE" --region "$AWS_REGION"
API_BASE="https://${REST_ID}.execute-api.${AWS_REGION}.amazonaws.com/${STAGE}"
```

## 5. 動作確認 (curl)
```sh
curl -s -X POST "$API_BASE/books" -H 'Content-Type: application/json' -d '{"title":"吾輩は猫である","author":"夏目漱石","publishedDate":"1905-01-01","status":"未読"}'
BOOK_ID="<戻りのbookId>"
curl -s "$API_BASE/books/$BOOK_ID"
curl -s "$API_BASE/books"
```

## 6. クリーンアップ
```sh
aws apigateway delete-rest-api --rest-api-id "$REST_ID" --region "$AWS_REGION"
aws lambda delete-function --function-name "$FUNCTION_NAME" --region "$AWS_REGION"
aws iam detach-role-policy --role-name BooksApiRole --policy-arn "arn:aws:iam::${ACCOUNT_ID}:policy/BooksApiDynamoDBPolicy"
aws iam delete-policy --policy-arn "arn:aws:iam::${ACCOUNT_ID}:policy/BooksApiDynamoDBPolicy"
aws iam delete-role --role-name BooksApiRole
aws dynamodb delete-table --table-name "$TABLE_NAME" --region "$AWS_REGION"
```
