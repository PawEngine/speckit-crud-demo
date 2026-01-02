# Phase 1 Data Model: Books API Update/Delete

**Entity: Book**
- `BookId` (PK, string/UUID)
- `title` (string, required; non-empty)
- `author` (string, required; non-empty)
- `status` (string, required; enum: `未読` | `読了`)
- `publishedDate` (string, optional; ISO-like)

**Relationships**
- None (single-table PK-only access)

**Validation Rules**
- `title`/`author`: non-empty string
- `status`: `未読` または `読了` のみ

**State Transitions**
- `status: 未読 → 読了`（更新でのみ遷移）
- その他の遷移は明示的要件なし

**Notes**
- Update は部分更新（未指定フィールドは現値維持）。
- Delete は物理削除、存在しない場合は 404。
