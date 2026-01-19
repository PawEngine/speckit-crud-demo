# Implementation Plan: Books API Update/Delete

**Branch**: `001-books-update-delete` | **Date**: 2026-01-02 | **Spec**: `specs/001-books-update-delete/spec.md`
**Input**: Update/Delete 機能の仕様に基づく段階的な拡張計画（既存 AWS リソースの差分適用）。

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

- 目的: 既存の Create/Read スタックへ非破壊で Update（PUT）/Delete（DELETE）を追加。
- 技術方針: Lambda ハンドラに PUT/DELETE を追加 → 関数コードを更新 → API Gateway に PUT/DELETE メソッドと Lambda Proxy 統合を追加。DynamoDB テーブル/IAM ロール/API は再利用。
- ロールバック: API Gateway メソッド削除 + Lambda コード復元で元状態（Create/Read）へ戻す。

## Technical Context

<!--
  ACTION REQUIRED: Replace the content in this section with the technical details
  for the project. The structure here is presented in advisory capacity to guide
  the iteration process.
-->

**Language/Version**: Python 3.11  
**Primary Dependencies**: boto3（Lambda 標準提供の SDK 利用）  
**Storage**: DynamoDB（テーブル名: `BooksTable`、PK: `BookId`）  
**Testing**: curl + jq による契約/統合テスト（TDD）  
**Target Platform**: AWS Lambda + API Gateway（REST API, Lambda Proxy）
**Project Type**: single project（サーバレスバックエンドのみ）  
**Performance Goals**: 憲章準拠（p95 < 200ms CRUD / 100 req/s ベースライン）  
**Constraints**: AWS CLI のみでプロビジョニング; 公開 API（認証なし）  
**Scale/Scope**: デモ規模（少数ユーザー、単一テーブル）

NEEDS CLARIFICATION: なし（Phase 0 研究で DELETE レスポンス 200+JSON を採用 により解消）。

### Existing Resources
- Lambda 関数: `BooksApiFunction`
- DynamoDB テーブル: `BooksTable`
- API Gateway: `API_NAME`（REST）; リソース `/books`, `/books/{bookId}` 既存
- 変数: `AWS_REGION`, `STAGE`, `ACCOUNT_ID`（`scripts/aws/00_env.sh`）

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

Status: PASS（本計画は AWS CLI の差分適用を明示）。

**Documentation & Scripts**
- Quickstart MUST be beginner-friendly and include AWS CLI prerequisites.
- Provisioning and operations scripts MUST be runnable as `sh` with Japanese comments.

## Project Structure

### Documentation (this feature)

```text
specs/[###-feature]/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

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

scripts/
└── aws/
  ├── 00_env.sh
  ├── 30_lambda.sh
  └── 40_apigw.sh

specs/001-books-update-delete/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
└── contracts/
  └── openapi.yaml

tests/
├── contract/
├── integration/
└── unit/
```

**Structure Decision**: Single project。既存バックエンド配下の Lambda ハンドラを拡張し、スクリプトは再利用。

## Execution Steps (AWS CLI)

Step 1: バックエンド（Lambda）のロジック拡張
- 変更ファイル: `src/lambda/books_handler.py`
- 実装: `PUT /books/{bookId}`（部分更新）・`DELETE /books/{bookId}`（物理削除）を追加。検証（status, 空文字）・存在チェック（404）・構造化エラーを既存方針で統一。

Step 2: Lambda 関数のコード更新
- パッケージングと反映:
```
mkdir -p .build && cp src/lambda/books_handler.py .build/ && (cd .build && zip -q books_handler.zip books_handler.py)
aws lambda update-function-code --function-name "$FUNCTION_NAME" --zip-file fileb://.build/books_handler.zip --region "$AWS_REGION"
aws lambda wait function-updated --function-name "$FUNCTION_NAME" --region "$AWS_REGION"
```

Step 3: API Gateway の設定拡張（PUT/DELETE メソッド追加 + 統合）
```
API_ID=$(aws apigateway get-rest-apis --region "$AWS_REGION" --query "items[?name=='$API_NAME'].id | [0]" --output text)
BOOK_ID_RES=$(aws apigateway get-resources --rest-api-id "$API_ID" --region "$AWS_REGION" --query "items[?path=='/books/{bookId}'].id | [0]" --output text)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
LAMBDA_ARN="arn:aws:lambda:$AWS_REGION:$ACCOUNT_ID:function:$FUNCTION_NAME"
URI="arn:aws:apigateway:$AWS_REGION:lambda:path/2015-03-31/functions/$LAMBDA_ARN/invocations"

aws apigateway put-method --rest-api-id "$API_ID" --resource-id "$BOOK_ID_RES" --http-method PUT --authorization-type NONE --no-api-key-required --region "$AWS_REGION"
aws apigateway put-method --rest-api-id "$API_ID" --resource-id "$BOOK_ID_RES" --http-method DELETE --authorization-type NONE --no-api-key-required --region "$AWS_REGION"

aws apigateway put-integration --rest-api-id "$API_ID" --resource-id "$BOOK_ID_RES" --http-method PUT --type AWS_PROXY --integration-http-method POST --uri "$URI" --region "$AWS_REGION"
aws apigateway put-integration --rest-api-id "$API_ID" --resource-id "$BOOK_ID_RES" --http-method DELETE --type AWS_PROXY --integration-http-method POST --uri "$URI" --region "$AWS_REGION"

aws lambda add-permission --function-name "$FUNCTION_NAME" --statement-id "apigw-put" --action "lambda:InvokeFunction" --principal apigateway.amazonaws.com --source-arn "arn:aws:execute-api:$AWS_REGION:$ACCOUNT_ID:$API_ID/*/PUT/books/*" --region "$AWS_REGION" || true
aws lambda add-permission --function-name "$FUNCTION_NAME" --statement-id "apigw-delete" --action "lambda:InvokeFunction" --principal apigateway.amazonaws.com --source-arn "arn:aws:execute-api:$AWS_REGION:$ACCOUNT_ID:$API_ID/*/DELETE/books/*" --region "$AWS_REGION" || true

aws apigateway create-deployment --rest-api-id "$API_ID" --stage-name "$STAGE" --region "$AWS_REGION"
```

Verification（curl）
```
API_BASE=$(cat .api_base_url)
BOOK_ID=$(curl -s -X POST "$API_BASE/books" -H 'Content-Type: application/json' -d '{"title":"初期","author":"著者","status":"未読"}' | jq -r .bookId)
curl -s -X PUT "$API_BASE/books/$BOOK_ID" -H 'Content-Type: application/json' -d '{"title":"改題","status":"読了"}' | jq .
curl -s -X DELETE "$API_BASE/books/$BOOK_ID" | jq .
curl -s -o /dev/null -w "%{http_code}\n" "$API_BASE/books/$BOOK_ID" # 404
```

Rollback（非破壊）
```
aws apigateway delete-method --rest-api-id "$API_ID" --resource-id "$BOOK_ID_RES" --http-method PUT --region "$AWS_REGION" || true
aws apigateway delete-method --rest-api-id "$API_ID" --resource-id "$BOOK_ID_RES" --http-method DELETE --region "$AWS_REGION" || true
aws apigateway create-deployment --rest-api-id "$API_ID" --stage-name "$STAGE" --region "$AWS_REGION"
aws lambda update-function-code --function-name "$FUNCTION_NAME" --zip-file fileb://.build/books_handler_prev.zip --region "$AWS_REGION"
```

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| [e.g., 4th project] | [current need] | [why 3 projects insufficient] |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient] |
