# Feature Specification: Lambda+DynamoDB 書籍管理API（Create/Read）

**Feature Branch**: `001-lambda-dynamodb-books-api`  
**Created**: 2025-12-27  
**Status**: Draft  
**Input**: サーバーレス構成（Lambda + DynamoDB）による書籍管理API。今回はCreate/Readを実装し、拡張可能な設計を採用。DynamoDBテーブル名は`BooksTable`（PK: `BookId`）。API GatewayはREST API。エンドポイント: `POST /books`, `GET /books/{bookId}`, `GET /books`（一覧）。

## User Scenarios & Testing *(mandatory)*

<!--
  IMPORTANT: User stories should be PRIORITIZED as user journeys ordered by importance.
  Each user story/journey must be INDEPENDENTLY TESTABLE - meaning if you implement just ONE of them,
  you should still have a viable MVP (Minimum Viable Product) that delivers value.
  
  Assign priorities (P1, P2, P3, etc.) to each story, where P1 is the most critical.
  Think of each story as a standalone slice of functionality that can be:
  - Developed independently
  - Tested independently
  - Deployed independently
  - Demonstrated to users independently
-->

### User Story 1 - 書籍の登録（Create） (Priority: P1)

ユーザーは書籍タイトル・著者・出版日（任意）をJSONで送信し、新規書籍を登録できる。`BookId`はサーバー側でUUIDを自動生成。`Status`は省略時に`未読`をデフォルト適用。

**Why this priority**: まず登録機能がなければデータが存在せず、以降の参照機能が成立しないため。

**Independent Test**: `curl`で`POST /books`にJSONを送信し、201と`BookId`が返ること、およびDynamoDBにレコードが保存されていることを確認すれば独立に成立。

**Acceptance Scenarios**:

1. **Given** DynamoDB `BooksTable` が存在し、API GatewayとLambdaが統合済、**When** `POST /books` に `{"title":"吾輩は猫である","author":"夏目漱石","publishedDate":"1905-01-01"}` を送信、**Then** 201と`{"bookId":"<UUID>"}` が返り、DynamoDBに同値が保存される。
2. **Given** 必須項目不足（例: `title`欠落）、**When** `POST /books`、**Then** 400とエラーJSON（`{"code":"VALIDATION_ERROR","message":"title is required"}`）。

テスト例（CLI）:
```bash
curl -s -X POST "$API_BASE/books" \
  -H 'Content-Type: application/json' \
  -d '{"title":"吾輩は猫である","author":"夏目漱石","publishedDate":"1905-01-01","status":"未読"}'
```

---

### User Story 2 - 書籍の参照（Read One） (Priority: P2)

ユーザーは`BookId`を指定して1件の書籍情報を取得できる。

**Why this priority**: 登録済みデータを確認できることがAPIの基本価値であり、Createと対で最小価値が成立するため。

**Independent Test**: `curl`で`GET /books/{bookId}`を実行し、存在時200で書籍JSON、非存在時404が返ることを確認すれば独立に成立。

**Acceptance Scenarios**:
1. **Given** `BookId=abc-123` のレコードが存在、**When** `GET /books/abc-123`、**Then** 200と対象レコードJSONが返る。
2. **Given** レコードが存在しない、**When** `GET /books/does-not-exist`、**Then** 404と`{"code":"NOT_FOUND","message":"book not found"}`が返る。

テスト例（CLI）:
```bash
curl -s "$API_BASE/books/$BOOK_ID"
```

---

### User Story 3 - 書籍一覧の参照（Read All） (Priority: P3)

ユーザーは登録済み書籍の一覧を取得できる。初期実装ではDynamoDBの`Scan`で最大100件まで返却し、`lastEvaluatedKey`でページネーション。

**Why this priority**: 一覧取得は利便性が高いが、Create/Read Oneに依存しない付加価値として後順位。

**Independent Test**: `curl`で`GET /books`を実行し、200で配列が返却されること、ページネーションが動作することを確認すれば独立に成立。

**Acceptance Scenarios**:
1. **Given** 複数レコードが存在、**When** `GET /books`、**Then** 200と`{"items":[...],"count":N}`が返る。
2. **Given** 101件以上が存在、**When** `GET /books?limit=100`、**Then** 200と100件＋`lastEvaluatedKey`が返る。

テスト例（CLI）:
```bash
curl -s "$API_BASE/books"
curl -s "$API_BASE/books?limit=100&startKey=$LAST_KEY"
```

---

[Add more user stories as needed, each with an assigned priority]

### Edge Cases

- 必須項目不足（`title`/`author`）：400と明確なメッセージを返す。
- `status`の不正値（許容: `未読`/`読了`）：400。
- 存在しない`bookId`：404。
- 大量件数の一覧：`limit`と`lastEvaluatedKey`で段階取得。
- DynamoDBスロットリング/一時障害：429/503相当のリトライ方針、ユーザ向けメッセージ。

## Requirements *(mandatory)*

<!--
  ACTION REQUIRED: The content in this section represents placeholders.
  Fill them out with the right functional requirements.
-->

### Functional Requirements

- **FR-001**: 構築前にAWS CLIで`BooksTable`（PK: `BookId`）、REST API、Lambda、統合を作成する手順を提示すること（CLIファースト）。
- **FR-002**: `POST /books`は`title`(必須), `author`(必須), `publishedDate`(任意), `status`(任意; 省略時`未読`)を受け取り、UUIDを生成した`bookId`でDynamoDBへ保存すること。
- **FR-003**: 入力バリデーションを行い、必須不足または不正値の場合は400でエラーJSON（`code`/`message`）を返すこと。
- **FR-004**: `GET /books/{bookId}`は存在時200で書籍JSON、非存在時404でエラーJSONを返すこと。
- **FR-005**: `GET /books`は一覧を返し、`limit`(デフォルト100)と`lastEvaluatedKey`でページネーションを提供すること。
- **FR-006**: レスポンスはJSONで返し、フィールドは`bookId`,`title`,`author`,`status`,`publishedDate`（存在時）を含むこと。
- **FR-007**: `curl`によるテスト例を仕様に含め、コピペで検証可能であること。
- **FR-008**: 公開（認証なし）アクセス前提で構築すること（今回は認証非対応）。

### Key Entities

- **Book**: 書籍レコードを表す。
  - `bookId` (UUID; Partition Key)
  - `title` (文字列; 必須)
  - `author` (文字列; 必須)
  - `status` (文字列; 許容値: `未読`/`読了`; デフォルト`未読`)
  - `publishedDate` (文字列; ISO形式; 任意)

## Success Criteria *(mandatory)*

<!--
  ACTION REQUIRED: Define measurable success criteria.
  These must be technology-agnostic and measurable.
-->

### Measurable Outcomes

- **SC-001**: `POST /books`のp95応答時間が1秒未満である（サンプルデータ、通常負荷）。
- **SC-002**: `GET /books/{bookId}`のp95応答時間が1秒未満である。
- **SC-003**: `GET /books`で100件取得時でもp95応答時間が2秒未満である。
- **SC-004**: 仕様の`curl`テスト手順を初心者がコピー＆ペーストで完了できる（成功率90%以上）。
