# Research: Lambda+DynamoDB 書籍管理API（Create/Read）

**Date**: 2025-12-27

## Unknowns & Decisions

- Decision: Region
  - Rationale: ap-northeast-1（東京）は日本ユーザーに低遅延
  - Alternatives considered: us-east-1（汎用）
  - Chosen: ap-northeast-1

- Decision: Lambda runtime
  - Rationale: Python 3.11 は安定・モジュールが軽量
  - Alternatives: Node.js 20
  - Chosen: Python 3.11

- Decision: DynamoDB billing mode
  - Rationale: 初期は不確実性が高くオンデマンドが適切
  - Alternatives: プロビジョンドスループット
  - Chosen: PAY_PER_REQUEST

- Decision: API Gateway type
  - Rationale: REST API はリソース/メソッドの明確な構造
  - Alternatives: HTTP API（低コスト/低レイテンシ）
  - Chosen: REST API（要件準拠）

- Decision: Public Access (No Auth)
  - Rationale: 憲章と要件により今回は認証非対応
  - Alternatives: IAM/Auth (後続拡張)
  - Chosen: Public

## Best Practices

- IAM: 最小権限（テーブル限定のPut/Get/Scan＋CloudWatch Logs）
- Lambda: 環境変数でテーブル名、boto3は内蔵を使用
- API GW: Lambda Proxy統合でシンプルなルーティング
- Scripts: `sh`/日本語コメント、idempotent（存在時はスキップ/waitで整合）
- Performance: p95目標をCIでベンチ（将来導入）
