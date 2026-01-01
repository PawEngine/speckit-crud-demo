# Implementation Plan: Lambda+DynamoDB 書籍管理API（Create/Read）

**Branch**: `001-lambda-dynamodb-books-api` | **Date**: 2025-12-27 | **Spec**: `./spec.md`
**Input**: Feature specification from `./spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

AWS CLIのみでプロビジョニングし、Lambda(Python) + DynamoDB + API Gateway(REST)で書籍管理のCreate/Readを提供する。依存順は「DynamoDB → IAM Role/Policy → Lambda → API Gateway」。ファイル構成はIamポリシーJSON、Lambdaコード、シェルスクリプト、OpenAPI契約、Quickstartを分離し、拡張(Update/Delete)に備える。

## Technical Context

<!--
  ACTION REQUIRED: Replace the content in this section with the technical details
  for the project. The structure here is presented in advisory capacity to guide
  the iteration process.
-->

**Language/Version**: Python 3.11 (Lambda runtime)  
**Primary Dependencies**: boto3(内蔵), awscli  
**Storage**: Amazon DynamoDB (Table: `BooksTable`, PK: `BookId` (S))  
**Testing**: curl による契約テスト、後続でpytest  
**Target Platform**: AWS Lambda + API Gateway (REST)  
**Project Type**: single  
**Performance Goals**: p95: Create/Read One < 1s, Read All(100件) < 2s  
**Constraints**: AWS CLIのみ/認証なし(今回はパブリック)/性能回帰>5%禁止  
**Scale/Scope**: 初期はCRUDのC/R、今後U/Dを拡張予定

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

**Quality Gates (MANDATORY)**
- Lint + format + static analysis pass.
- Tests-first (TDD): failing tests written before implementation.
- Coverage: unit ≥ 80%, integration ≥ 70% on changed packages.
- Performance: no >5% regression on critical path benchmarks.
- Accessibility: no WCAG 2.1 AA violations (for UI changes).
- Security: no HIGH/CRITICAL dependency issues.

**Platform Constraints (AWS ONLY)**
- Provisioning MUST be via AWS CLI commands; no Terraform/CFN/CDK/Console.
- Backend MUST be AWS Lambda (Python 3.10+ or Node.js 20+) with DynamoDB + API Gateway.
- Provisioning Plan MUST be documented and executed BEFORE implementation.
- Authentication: out of scope (public access for now).

**Documentation & Scripts**
- Quickstart MUST be beginner-friendly and include AWS CLI prerequisites.
- Provisioning and operations scripts MUST be runnable as `sh` with Japanese comments.

Compliance: 本計画はCLIファースト、テスト/UX/性能/品質ゲートを満たす構成で進める。2025-12-27に仕様・計画・タスクの整合を再確認（T014）。

## Project Structure

### Documentation (this feature)

```text
specs/001-lambda-dynamodb-books-api/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

## Performance Smoke Tests

目標（p95）: Create/Read One < 1s、Read All(100件) < 2s。
簡易計測は `curl -w` を使用:

```sh
API_BASE=$(cat .api_base_url)

curl -s -o /dev/null -w 'POST %{{time_total}}s\n' -X POST "$API_BASE/books" \
  -H 'Content-Type: application/json' \
  -d '{"title":"perf","author":"test","status":"未読"}'

curl -s -o /dev/null -w 'GET one %{{time_total}}s\n' "$API_BASE/books/$BOOK_ID"

curl -s -o /dev/null -w 'GET all %{{time_total}}s\n' "$API_BASE/books"
```

閾値超過時はロギング/スキャン条件見直し、メモリ/タイムアウト調整（`30_lambda.sh`の`--memory-size`/`--timeout`）を検討。

### Source Code (repository root)
<!--
  ACTION REQUIRED: Replace the placeholder tree below with the concrete layout
  for this feature. Delete unused options and expand the chosen structure with
  real paths (e.g., apps/admin, packages/something). The delivered plan must
  not include Option labels.
-->

```text
src/
└── lambda/
  └── books_handler.py

iam/
└── policies/
  ├── lambda-trust-policy.json
  └── lambda-dynamodb-policy.json

scripts/aws/
├── 00_env.sh
├── 10_dynamodb.sh
├── 20_iam.sh
├── 30_lambda.sh
├── 40_apigw.sh
└── 90_cleanup.sh

# [REMOVE IF UNUSED] Option 2: Web application (when "frontend" + "backend" detected)
backend/
├── src/
│   ├── models/
│   ├── services/
│   └── api/
└── tests/

frontend/
├── src/
│   ├── components/
│   ├── pages/
│   └── services/
└── tests/

# [REMOVE IF UNUSED] Option 3: Mobile + API (when "iOS/Android" detected)
api/
└── [same as backend above]

ios/ or android/
└── [platform-specific structure: feature modules, UI flows, platform tests]
```

**Structure Decision**: [Document the selected structure and reference the real
directories captured above]
Structure Decision: 単一プロジェクト配下に`src/lambda`・`iam/policies`・`scripts/aws`・`specs/.../contracts`を配置する。将来U/D追加時は`books_handler.py`をモジュール分割し、関数を拡張する。

## Phased Plan (AWS CLI)

> 依存順: 1) DynamoDB → 2) IAM → 3) Lambda → 4) API Gateway

Common env (`scripts/aws/00_env.sh`):
```sh
#!/usr/bin/env sh
set -eu
# 必要に応じて上書き
export AWS_REGION="ap-northeast-1"
export STAGE="v1"
export TABLE_NAME="BooksTable"
export FUNCTION_NAME="BooksApiFunction"
export API_NAME="BooksApi"
export ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
```

Step 1: DynamoDB (`scripts/aws/10_dynamodb.sh`)
```sh
#!/usr/bin/env sh
set -eu
. "$(dirname "$0")/00_env.sh"
# テーブル作成（オンデマンド）
aws dynamodb create-table \
  --table-name "$TABLE_NAME" \
  --attribute-definitions AttributeName=BookId,AttributeType=S \
  --key-schema AttributeName=BookId,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region "$AWS_REGION"
aws dynamodb wait table-exists --table-name "$TABLE_NAME" --region "$AWS_REGION"
```

Step 2: IAM (`scripts/aws/20_iam.sh` + `iam/policies/*.json`)
`iam/policies/lambda-trust-policy.json`:
```json
{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"lambda.amazonaws.com"},"Action":"sts:AssumeRole"}]}
```
`iam/policies/lambda-dynamodb-policy.json`:
```json
{"Version":"2012-10-17","Statement":[
 {"Effect":"Allow","Action":["dynamodb:PutItem","dynamodb:GetItem","dynamodb:Scan"],"Resource":"arn:aws:dynamodb:*:*:table/BooksTable"},
 {"Effect":"Allow","Action":["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"],"Resource":"*"}
]}
```
作成スクリプト:
```sh
#!/usr/bin/env sh
set -eu
. "$(dirname "$0")/00_env.sh"
TRUST="iam/policies/lambda-trust-policy.json"
POLICY="iam/policies/lambda-dynamodb-policy.json"
aws iam create-role --role-name BooksApiRole --assume-role-policy-document file://"$TRUST"
aws iam create-policy --policy-name BooksApiDynamoDBPolicy --policy-document file://"$POLICY"
aws iam attach-role-policy --role-name BooksApiRole --policy-arn "arn:aws:iam::${ACCOUNT_ID}:policy/BooksApiDynamoDBPolicy"
# ロールが有効化されるまで少し待機
sleep 10
ROLE_ARN=$(aws iam get-role --role-name BooksApiRole --query 'Role.Arn' --output text)
echo "$ROLE_ARN" > .role_arn
```

Step 3: Lambda (`scripts/aws/30_lambda.sh` + `src/lambda/books_handler.py`)
`src/lambda/books_handler.py` ハンドラ仕様:
```python
# 日本語コメントで意図を説明。boto3でDynamoDBへPut/Get/Scanを実施。
# handler: books_handler.lambda_handler
```
作成スクリプト:
```sh
#!/usr/bin/env sh
set -eu
. "$(dirname "$0")/00_env.sh"
ROLE_ARN="$(cat .role_arn)"
ZIP=.build/lambda.zip
mkdir -p .build
zip -r "$ZIP" src/lambda -x "*.pyc" "__pycache__/*"
aws lambda create-function \
  --function-name "$FUNCTION_NAME" \
  --runtime python3.11 \
  --role "$ROLE_ARN" \
  --handler lambda/books_handler.lambda_handler \
  --zip-file fileb://"$ZIP" \
  --environment Variables="TABLE_NAME=$TABLE_NAME" \
  --timeout 10 --memory-size 256 \
  --region "$AWS_REGION"
```

Step 4: API Gateway (`scripts/aws/40_apigw.sh`)
```sh
#!/usr/bin/env sh
set -eu
. "$(dirname "$0")/00_env.sh"
REST_ID=$(aws apigateway create-rest-api --name "$API_NAME" --region "$AWS_REGION" --query id --output text)
ROOT_ID=$(aws apigateway get-resources --rest-api-id "$REST_ID" --region "$AWS_REGION" --query 'items[?path==`/`].id' --output text)
# /books, /books/{bookId}
BOOKS_ID=$(aws apigateway create-resource --rest-api-id "$REST_ID" --parent-id "$ROOT_ID" --path-part books --region "$AWS_REGION" --query id --output text)
BOOK_ID=$(aws apigateway create-resource --rest-api-id "$REST_ID" --parent-id "$BOOKS_ID" --path-part {bookId} --region "$AWS_REGION" --query id --output text)
# Methods
aws apigateway put-method --rest-api-id "$REST_ID" --resource-id "$BOOKS_ID" --http-method POST --authorization-type "NONE" --region "$AWS_REGION"
aws apigateway put-method --rest-api-id "$REST_ID" --resource-id "$BOOK_ID"  --http-method GET  --authorization-type "NONE" --region "$AWS_REGION"
aws apigateway put-method --rest-api-id "$REST_ID" --resource-id "$BOOKS_ID" --http-method GET  --authorization-type "NONE" --region "$AWS_REGION"
# Integrations (Lambda proxy)
LAMBDA_ARN="arn:aws:lambda:${AWS_REGION}:${ACCOUNT_ID}:function:${FUNCTION_NAME}"
URI="arn:aws:apigateway:${AWS_REGION}:lambda:path/2015-03-31/functions/${LAMBDA_ARN}/invocations"
for RID in "$BOOKS_ID" "$BOOK_ID"; do
  METHOD=$( [ "$RID" = "$BOOK_ID" ] && echo GET || echo POST )
  aws apigateway put-integration --rest-api-id "$REST_ID" --resource-id "$RID" --http-method "$METHOD" \
    --type AWS_PROXY --integration-http-method POST --uri "$URI" --region "$AWS_REGION"
done
# Permission for API GW to invoke Lambda
aws lambda add-permission --function-name "$FUNCTION_NAME" --statement-id apigw-invoke-post \
  --action lambda:InvokeFunction --principal apigateway.amazonaws.com \
  --source-arn "arn:aws:execute-api:${AWS_REGION}:${ACCOUNT_ID}:${REST_ID}/*/*/*"
# Deploy
aws apigateway create-deployment --rest-api-id "$REST_ID" --stage-name "$STAGE" --region "$AWS_REGION"
echo "https://${REST_ID}.execute-api.${AWS_REGION}.amazonaws.com/${STAGE}" > .api_base
```

Smoke Test (curl):
```sh
API_BASE=$(cat .api_base)
curl -s -X POST "$API_BASE/books" -H 'Content-Type: application/json' \
  -d '{"title":"吾輩は猫である","author":"夏目漱石","publishedDate":"1905-01-01","status":"未読"}'
BOOK_ID="<上の応答のbookId>"
curl -s "$API_BASE/books/$BOOK_ID"
curl -s "$API_BASE/books"
```

Cleanup (`scripts/aws/90_cleanup.sh`):
```sh
#!/usr/bin/env sh
set -eu
. "$(dirname "$0")/00_env.sh"
[ -f .api_base ] && API_ID=$(cut -d/ -f3 .api_base | cut -d. -f1) || API_ID=""
[ -n "$API_ID" ] && aws apigateway delete-rest-api --rest-api-id "$API_ID" --region "$AWS_REGION" || true
aws lambda delete-function --function-name "$FUNCTION_NAME" --region "$AWS_REGION" || true
aws iam detach-role-policy --role-name BooksApiRole --policy-arn "arn:aws:iam::${ACCOUNT_ID}:policy/BooksApiDynamoDBPolicy" || true
aws iam delete-policy --policy-arn "arn:aws:iam::${ACCOUNT_ID}:policy/BooksApiDynamoDBPolicy" || true
aws iam delete-role --role-name BooksApiRole || true
aws dynamodb delete-table --table-name "$TABLE_NAME" --region "$AWS_REGION" || true
```

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| [e.g., 4th project] | [current need] | [why 3 projects insufficient] |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient] |
