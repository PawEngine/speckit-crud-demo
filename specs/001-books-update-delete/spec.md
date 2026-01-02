# Feature Specification: Books API Update/Delete

**Feature Branch**: `001-books-update-delete`  
**Created**: 2026-01-02  
**Status**: Draft  
**Input**: 既存のBooks APIに更新（PUT）と削除（DELETE）機能を追加する。Lambda + API Gateway を拡張し、AWS CLI更新手順と curl テスト手順を含める。

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

### User Story 1 - 書籍の更新（Update） (Priority: P1)

既存の書籍に対して `title`/`author`/`status` を更新できる。`PUT /books/{bookId}` を呼ぶと、指定IDのレコードが上書きされる（未指定のフィールドは従来値を維持）。

**Why this priority**: 既存データの編集を可能にし、登録済み書籍の管理体験を完成させるため。

**Independent Test**: curl で PUT を実行し、続けて GET で値が更新されていることを確認する（ID既存/存在しない場合の両方を検証）。

**Acceptance Scenarios**:

1. **Given** 既存書籍が存在, **When** `PUT /books/{bookId}` で `title` を変更, **Then** `GET /books/{bookId}` で新しい `title` が返る
2. **Given** 既存書籍が存在, **When** `PUT /books/{bookId}` で `status=読了` を指定, **Then** `GET` で `status=読了` が返る
3. **Given** 書籍が存在しない, **When** `PUT /books/{bookId}` を呼ぶ, **Then** 404 JSON を返す
4. **Given** `status` が不正値, **When** `PUT` を呼ぶ, **Then** 400 JSON（検証エラー）を返す

---

### User Story 2 - 書籍の削除（Delete） (Priority: P2)

既存の書籍を削除できる。`DELETE /books/{bookId}` を呼ぶと、該当レコードがテーブルから消える。

**Why this priority**: 不要データの整理と、一覧の品質維持のため。

**Independent Test**: curl で DELETE を実行し、続けて GET が 404 を返すことを確認する。

**Acceptance Scenarios**:

1. **Given** 既存書籍が存在, **When** `DELETE /books/{bookId}`, **Then** `GET /books/{bookId}` は 404 を返す
2. **Given** 書籍が存在しない, **When** `DELETE /books/{bookId}`, **Then** 404 JSON を返す（冪等な削除とするかは要件次第だが、今回は404とする）

---

### User Story 3 - 更新/削除の一覧反映（List Consistency） (Priority: P3)

更新・削除後に `GET /books` の結果へ即時反映される（更新後の値・削除後の消失）。

**Why this priority**: 一覧と詳細の整合性維持のため。

**Independent Test**: 更新・削除後に一覧を取得し、件数・内容が期待通りであることを確認。

**Acceptance Scenarios**:

1. **Given** 書籍を更新, **When** `GET /books`, **Then** 更新後の値が反映されている
2. **Given** 書籍を削除, **When** `GET /books`, **Then** 該当IDが一覧から消える

---

[Add more user stories as needed, each with an assigned priority]

### Edge Cases

- `PUT` でボディが空/JSON不正：400 JSON を返す
- `PUT` で許容外 `status`：400 JSON を返す（許容値は `未読`/`読了`）
- `PUT` で `title`/`author` が空文字：400 JSON を返す
- `DELETE` の連続呼び出し：2回目以降は404（冪等に200を返す設計もあるが、今回は404とする）
- 大量更新/削除時の整合性：APIは単発操作を提供（バルクはスコープ外）

## Requirements *(mandatory)*

### Functional Requirements

- **FR-UD-001**: API MUST support `PUT /books/{bookId}` to update `title`/`author`/`status` with validation（`status ∈ {未読, 読了}`、空文字不可）。
- **FR-UD-002**: API MUST return 404 for `PUT` when target `bookId` does not exist.
- **FR-UD-003**: API MUST support `DELETE /books/{bookId}` and remove the item permanently.
- **FR-UD-004**: API MUST return 404 for `DELETE` when target `bookId` does not exist.
- **FR-UD-005**: `GET /books` MUST reflect latest updates/deletions immediately.
- **FR-UD-006**: Error responses MUST be structured JSON with `code`/`message` fields（既存フォーマットに準拠）。
- **FR-UD-007**: DynamoDB `BooksTable`（PK: `BookId`） MUST remain as the single source of truth。
- **FR-UD-008**: Validation failures MUST result in 400; unexpected errors in 500; DynamoDB errors in 503。

Assumptions:
- `status` 許容値は `未読`/`読了`。
- `PUT` は部分更新（未指定項目は維持）。
- 削除は物理削除。

### Key Entities *(include if feature involves data)*

- **Book**: `BookId`, `title`, `author`, `status`, `publishedDate?`
  - `status`: 許容値は `未読`/`読了`
  - `BookId`: 既存UUID（Createで付与済み）

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-UD-001**: 更新操作は 95% のケースで 1 秒未満で完了し、GET で即時反映される。
- **SC-UD-002**: 削除操作は 95% のケースで 1 秒未満で完了し、GET で 404/一覧反映が確認できる。
- **SC-UD-003**: 受入テスト（curl）において、更新/削除の正常系・異常系をすべてパスする。
- **SC-UD-004**: 仕様に準拠した構造化エラーレスポンス比率 100%。

---

## User Scenarios & Testing *(追加の検証手順)*

以下は受入テストの一例（技術詳細は仕様外だが、検証のため記載）。

```sh
API_BASE=$(cat .api_base_url)

# 1) 事前に1件作成
BOOK_ID=$(curl -s -X POST "$API_BASE/books" -H 'Content-Type: application/json' -d '{"title":"初期","author":"著者","status":"未読"}' | jq -r .bookId)

# 2) 更新（title/status変更）
curl -s -X PUT "$API_BASE/books/$BOOK_ID" -H 'Content-Type: application/json' -d '{"title":"改題","status":"読了"}' | jq .
# 確認
curl -s "$API_BASE/books/$BOOK_ID" | jq .

# 3) 削除
curl -s -X DELETE "$API_BASE/books/$BOOK_ID" | jq .
# 確認（404）
curl -s -w "\n%{http_code}\n" "$API_BASE/books/$BOOK_ID"

# 4) 異常系（不正status）
curl -s -w "\n%{http_code}\n" -X PUT "$API_BASE/books/$BOOK_ID" -H 'Content-Type: application/json' -d '{"status":"不正"}'
```

Notes:
- `status` は `未読`/`読了` のみ有効。その他は 400。
- `PUT` で未指定項目は既存値を維持する設計（上書きのみ）。
