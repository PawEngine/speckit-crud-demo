---

description: "Tasks for Lambda+DynamoDB 書籍管理API（Create/Read）"
---

# Tasks: Lambda+DynamoDB 書籍管理API（Create/Read）

**Input**: Design documents from `/specs/001-lambda-dynamodb-books-api/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/

**Tests**: Per constitution, tests are MANDATORY and MUST be written first for each user story. CI MUST fail until tests pass and coverage gates are met.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Phase 0: AWS Provisioning (AWS CLI only)

**Purpose**: Provision required AWS resources using AWS CLI BEFORE any implementation

- [ ] T001 Create env script in scripts/aws/00_env.sh
- [ ] T002 [P] Write DynamoDB create script in scripts/aws/10_dynamodb.sh
- [ ] T003 [P] Add IAM trust policy in iam/policies/lambda-trust-policy.json
- [ ] T004 [P] Add IAM DynamoDB policy in iam/policies/lambda-dynamodb-policy.json
- [ ] T005 Create IAM setup script in scripts/aws/20_iam.sh
- [ ] T006 Create Lambda deploy script in scripts/aws/30_lambda.sh
- [ ] T007 Create API Gateway script in scripts/aws/40_apigw.sh
- [ ] T008 Create cleanup script in scripts/aws/90_cleanup.sh
- [ ] T009 [P] Document copy-paste steps in specs/001-lambda-dynamodb-books-api/quickstart.md

**Checkpoint**: All scripts exist with Japanese comments and are idempotent

---

## Phase 1: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure scaffolding required by all user stories

- [ ] T010 Ensure OpenAPI contract covers POST/GET in specs/001-lambda-dynamodb-books-api/contracts/openapi.yaml
- [ ] T011 [P] Create handler module in src/lambda/books_handler.py
- [ ] T012 Add logging and structured JSON responses in src/lambda/books_handler.py
- [ ] T013 [P] Add basic error handling for DynamoDB operations in src/lambda/books_handler.py
- [ ] T014 Validate plan.md consistency with constitution in specs/001-lambda-dynamodb-books-api/plan.md

**⚠️ CRITICAL**: Complete before any user story tasks

---

## Phase 2: User Story 1 - 書籍の登録（Create） (Priority: P1) 🎯 MVP

**Goal**: Register a new book via `POST /books` with UUID assignment

**Independent Test**: `curl -X POST` returns 201 with `bookId`, item persisted in DynamoDB

### Tests for User Story 1 (MANDATORY)

- [ ] T020 [P] [US1] Add contract test script tests/contract/us1_post_books.sh
- [ ] T021 [P] [US1] Add integration test script tests/integration/us1_create_and_get.sh

### Implementation for User Story 1

- [ ] T022 [P] [US1] Implement POST /books path in src/lambda/books_handler.py
- [ ] T023 [US1] Validate input and return 400 on errors in src/lambda/books_handler.py
- [ ] T024 [US1] DynamoDB PutItem with fields in src/lambda/books_handler.py
- [ ] T025 [US1] Update quickstart with US1 curl in specs/001-lambda-dynamodb-books-api/quickstart.md

**Checkpoint**: POST /books independently functional and testable

---

## Phase 3: User Story 2 - 書籍の参照（Read One） (Priority: P2)

**Goal**: Fetch a book by `bookId` via `GET /books/{bookId}`

**Independent Test**: `curl -s $API_BASE/books/$BOOK_ID` returns 200 or 404 accordingly

### Tests for User Story 2 (MANDATORY)

- [ ] T030 [P] [US2] Add contract test script tests/contract/us2_get_book.sh

### Implementation for User Story 2

- [ ] T031 [P] [US2] Implement GET /books/{bookId} in src/lambda/books_handler.py
- [ ] T032 [US2] Map DynamoDB item to API JSON fields in src/lambda/books_handler.py
- [ ] T033 [US2] Return 404 JSON when not found in src/lambda/books_handler.py

**Checkpoint**: GET /books/{bookId} independently functional and testable

---

## Phase 4: User Story 3 - 書籍一覧の参照（Read All） (Priority: P3)

**Goal**: List books with pagination via `GET /books`

**Independent Test**: `curl -s $API_BASE/books` returns items and count; pagination works

### Tests for User Story 3 (MANDATORY)

- [ ] T040 [P] [US3] Add contract test script tests/contract/us3_list_books.sh

### Implementation for User Story 3

- [ ] T041 [P] [US3] Implement GET /books in src/lambda/books_handler.py
- [ ] T042 [US3] Support limit and lastEvaluatedKey in src/lambda/books_handler.py
- [ ] T043 [US3] Return items/count and optional lastEvaluatedKey in src/lambda/books_handler.py

**Checkpoint**: Read All independently functional and testable

---

## Phase N: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [ ] T090 [P] Add docs for cleanup & rollback in specs/001-lambda-dynamodb-books-api/quickstart.md
- [ ] T091 Add performance smoke test notes in specs/001-lambda-dynamodb-books-api/plan.md
- [ ] T092 [P] Refactor handler into smaller functions in src/lambda/books_handler.py
- [ ] T093 Security: verify IAM policy minimum-privilege in iam/policies/lambda-dynamodb-policy.json

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 0 (Provisioning Scripts)**: No dependencies - start immediately
- **Phase 1 (Foundational)**: Depends on Phase 0 completion - BLOCKS all user stories
- **User Stories (Phase 2+)**: All depend on Foundational completion
- **Polish**: After desired stories complete

### User Story Dependencies

- **User Story 1 (P1)**: Starts after Foundational - No story dependency
- **User Story 2 (P2)**: Starts after Foundational - Independent (uses created data)
- **User Story 3 (P3)**: Starts after Foundational - Independent

### Within Each User Story

- Tests MUST be written and FAIL before implementation
- Implement route handler after tests
- Validate errors and success cases
- Verify story independently via curl before proceeding

### Parallel Opportunities

- Phase 0 scripts (T002–T008) can be authored in parallel
- Foundational T011 and T013 can proceed in parallel
- Within stories, model-free tasks (e.g., tests) can run in parallel
- Different user stories can be developed in parallel after Phase 1

---

## Parallel Example: User Story 1

```bash
# Run tests together (after API is deployed):
sh tests/contract/us1_post_books.sh &
sh tests/integration/us1_create_and_get.sh &
wait
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 0 + Phase 1
2. Implement US1 (Create) and validate via curl
3. Deploy/demo if ready

### Incremental Delivery

1. Add US2 (Read One) → Test independently → Deploy/Demo
2. Add US3 (Read All) → Test independently → Deploy/Demo
3. Each story adds value without breaking previous stories
