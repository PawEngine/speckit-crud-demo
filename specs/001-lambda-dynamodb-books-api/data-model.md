# Data Model: Book (DynamoDB)

## Entity: Book
- `bookId` (String, PK)
- `title` (String, required)
- `author` (String, required)
- `status` (String, enum: `未読`|`読了`, default `未読`)
- `publishedDate` (String, ISO-8601, optional)

## Table
- Name: `BooksTable`
- Partition Key: `BookId` (S)
- Billing: On-Demand (PAY_PER_REQUEST)

## Validation Rules
- title/author: 非空文字
- status: 許容値のみ。省略時は`未読`
- publishedDate: `YYYY-MM-DD` 形式

## State Transitions
- `未読` → `読了`（将来Updateで実装予定）
