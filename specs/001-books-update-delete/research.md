# Phase 0 Research: Books API Update/Delete

**Context**: 既存の Create/Read 実装（Lambda + API Gateway + DynamoDB）を拡張し、破壊的変更なく Update/Delete を追加する。

## Decisions

- **DELETE のレスポンス形式**
  - Decision: `200 OK` + JSON（例: `{ "deleted": true, "bookId": "..." }`）。
  - Rationale: 既存の受入テスト例で JSON を確認しやすく、CLIの自動化にも向く。
  - Alternatives: `204 No Content`（REST的に自然だが、検証容易性が低い）／`202 Accepted`（非同期前提のため不採用）。

- **PUT の更新方式**
  - Decision: 部分更新。未指定フィールドは現値維持。`status` は `未読`/`読了` のみ。
  - Rationale: スペック準拠、UI無し前提でシンプルかつ予測可能。
  - Alternatives: 全フィールド必須の完全上書き（冪等性は高いが、使い勝手が低下）。

- **存在検証（Conditional）**
  - Decision: `get_item` で存在確認し、非存在なら 404 を返す。
  - Rationale: 明示的なメッセージ性（NOT_FOUND）と分岐が分かりやすい。
  - Alternatives: `UpdateItem` の条件式（`ConditionExpression`）で存在チェック：DynamoDB設計的には適切だが、ハンドラ分岐が読みやすい方を採用。

- **権限と公開**
  - Decision: 既存の Lambda 実行ロールと API Gateway 統合を再利用。追加権限は不要（DynamoDBに対してPut/Get/Scan/Deleteを既に許容）。
  - Rationale: 既存ポリシーがテーブルスコープで最小権限化されている前提。
  - Alternatives: 明示的に `UpdateItem` のみ付与などの再最小化：要ポリシー編集。今回の差分では不要。

## Best Practices

- API Gateway: `PUT`/`DELETE` メソッドは `--authorization-type NONE --no-api-key-required` を明示し、Lambda Proxy 統合を利用。
- Lambda: ルーティングは `httpMethod` と `path` の組み合わせで明確化。日本語コメントと構造化エラーレスポンス（`code`/`message`）。
- DynamoDB: Item 形状は Create/Read と同一。不要データは物理削除。
- Rollback: メソッド削除 (`delete-method`) と Lambda コードの再デプロイで元状態へ復帰。

## Resolved Unknowns

- DELETE の HTTP ステータス（200 vs 204）→ 200 を採用。
- 部分更新/全体更新の方式→ 部分更新を採用。
- 非存在時の扱い（PUT/DELETE）→ 404 を返す。
