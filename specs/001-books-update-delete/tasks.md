# Tasks: Books API Update/Delete

**Input**: Design documents from `specs/001-books-update-delete/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/

**Tests**: 憲章準拠（TDD）。各ユーザーストーリーのテストは実装前に作成し、最初は FAIL であること。

**Organization**: ユーザーストーリー単位で独立実装・独立検証可能に整理。

---

## Phase 1: Setup (Project Initialization)

- [ ] T001 仕様・計画ファイル確認（`specs/001-books-update-delete/spec.md`, `plan.md`）
- [ ] T002 [P] 既存環境変数の読み込みを確認（`scripts/aws/00_env.sh`）
- [ ] T003 [P] OpenAPI 契約の配置確認（`specs/001-books-update-delete/contracts/openapi.yaml`）
- [ ] T004 [P] Quickstart 手順の確認（`specs/001-books-update-delete/quickstart.md`）

---

## Phase 2: Foundational (Blocking Prerequisites)

- [ ] T005 [P] 既存 Lambda 関数名/テーブル/API の検証（`scripts/aws/00_env.sh`）
- [ ] T006 [P] API Gateway の `/books/{bookId}` リソース存在確認（AWS CLI）
- [ ] T007 ロギング・エラーフォーマットの統一方針確認（`src/lambda/books_handler.py`）

Checkpoint: Foundational 完了後、ユーザーストーリーへ進行。

---

## Phase 3: User Story 1 - 書籍の更新（Update） (Priority: P1) 🎯 MVP

**Goal**: `PUT /books/{bookId}` により部分更新（title/author/status/publishedDate）。
**Independent Test**: PUT → GET で更新内容の反映を確認（存在しないIDは404）。

### Tests for User Story 1（TDD）
- [ ] T010 [P] [US1] 契約テストスクリプトを追加（`tests/contract/us4_update_book.sh`）
- [ ] T011 [P] [US1] 統合テストスクリプトを追加（`tests/integration/us4_update_flow.sh`）

### Implementation for User Story 1
- [ ] T012 [US1] Lambda ハンドラへ PUT ルート追加（`src/lambda/books_handler.py`）
- [ ] T013 [US1] 入力検証（空文字/不正 status）実装（`src/lambda/books_handler.py`）
- [ ] T014 [US1] 既存レコードの取得と404応答（`src/lambda/books_handler.py`）
- [ ] T015 [US1] 部分更新ロジック実装（`src/lambda/books_handler.py`）
- [ ] T016 [US1] 更新結果の JSON 応答（`src/lambda/books_handler.py`）
- [ ] T017 [US1] Lambda コードのデプロイ（`aws lambda update-function-code`）
- [ ] T018 [P] [US1] API Gateway に PUT メソッド追加（`aws apigateway put-method`）
- [ ] T019 [P] [US1] PUT 統合（Lambda Proxy）追加（`aws apigateway put-integration`）
- [ ] T020 [US1] デプロイ（`aws apigateway create-deployment`）
- [ ] T021 [US1] 受入テスト（curl）実行（`specs/001-books-update-delete/quickstart.md`）

Checkpoint: US1 単独で完全機能・独立検証可。

---

## Phase 4: User Story 2 - 書籍の削除（Delete） (Priority: P2)

**Goal**: `DELETE /books/{bookId}` により該当レコードを物理削除。
**Independent Test**: DELETE → GET が 404 を返すことを確認。

### Tests for User Story 2（TDD）
- [ ] T022 [P] [US2] 契約テストスクリプトを追加（`tests/contract/us5_delete_book.sh`）
- [ ] T023 [P] [US2] 統合テストスクリプトを追加（`tests/integration/us5_delete_flow.sh`）

### Implementation for User Story 2
- [ ] T024 [US2] Lambda ハンドラへ DELETE ルート追加（`src/lambda/books_handler.py`）
- [ ] T025 [US2] 既存確認と404応答（`src/lambda/books_handler.py`）
- [ ] T026 [US2] 削除ロジックと JSON 応答（`src/lambda/books_handler.py`）
- [ ] T027 [US2] Lambda コードのデプロイ（`aws lambda update-function-code`）
- [ ] T028 [P] [US2] API Gateway に DELETE メソッド追加（`aws apigateway put-method`）
- [ ] T029 [P] [US2] DELETE 統合（Lambda Proxy）追加（`aws apigateway put-integration`）
- [ ] T030 [US2] デプロイ（`aws apigateway create-deployment`）
- [ ] T031 [US2] 受入テスト（curl）実行（`specs/001-books-update-delete/quickstart.md`）

Checkpoint: US1/US2 それぞれ独立に機能・検証可。

---

## Phase 5: User Story 3 - 更新/削除の一覧反映（List Consistency） (Priority: P3)

**Goal**: 更新・削除後に `GET /books` に即時反映。
**Independent Test**: 更新→一覧に更新値反映／削除→一覧から消える。

### Tests for User Story 3（TDD）
- [ ] T032 [P] [US3] 統合テスト（`tests/integration/us6_list_consistency.sh`）

### Implementation for User Story 3
- [ ] T033 [US3] 一覧取得の確認（`src/lambda/books_handler.py`）
- [ ] T034 [US3] 受入テスト（curl）実行（`specs/001-books-update-delete/quickstart.md`）

Checkpoint: 3ストーリーすべて独立検証可。

---

## Final Phase: Polish & Cross-Cutting Concerns

- [ ] T035 [P] ドキュメント更新（`specs/001-books-update-delete/quickstart.md`）
- [ ] T036 コード整形・軽微なリファクタリング（`src/lambda/books_handler.py`）
- [ ] T037 [P] パフォーマンス簡易検証（`curl -w` を用いた p95 確認）
- [ ] T038 セキュリティハードニング（`aws lambda add-permission` の `source-arn` を最小化）
- [ ] T039 [P] ロールバック手順の検証（PUT/DELETE メソッド削除 + Lambda 復元）

---

## Dependencies & Execution Order

- Setup → Foundational → US1 → US2 → US3 → Polish
- 各ストーリーは Foundational 完了後に独立着手可（優先度順を推奨）。

### User Story Dependencies
- US1（P1）: Foundational 完了後に開始、他ストーリー非依存
- US2（P2）: Foundational 完了後に開始、US1非依存（独立検証）
- US3（P3）: Foundational 完了後に開始、US1/US2の結果が一覧に反映されることを確認

### Parallel Opportunities
- [P] テストスクリプト作成は実装と別ファイルのため並行化可能
- [P] API Gateway メソッド追加とドキュメント更新は並行可
- [P] パフォーマンス検証とドキュメント更新は並行可

## Implementation Strategy

- MVP: US1 を最優先（PUT 更新）。
- Incremental: US1 → US2 → US3 の順に小さく配信。

