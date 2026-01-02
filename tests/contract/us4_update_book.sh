#!/usr/bin/env sh
# 契約テスト: US4 PUT /books/{bookId}
set -eu
API_BASE=${API_BASE:-$(cat .api_base_url 2>/dev/null || true)}
[ -n "${API_BASE:-}" ] || { echo "[ERROR] API_BASE not set and .api_base_url not found"; exit 1; }
which jq >/dev/null 2>&1 || { echo "[ERROR] jq is required"; exit 1; }

# まず1件作成
create=$(curl -s -X POST "$API_BASE/books" -H 'Content-Type: application/json' \
  -d '{"title":"最初の題","author":"著者","status":"未読"}')
bookId=$(printf "%s" "$create" | jq -r .bookId)
[ -n "$bookId" ] && [ "$bookId" != "null" ] || { echo "[FAIL] create failed"; exit 1; }

# 更新
resp=$(curl -s -w "\n%{http_code}" -X PUT "$API_BASE/books/$bookId" -H 'Content-Type: application/json' \
  -d '{"title":"改題","status":"読了"}')
body=$(printf "%s" "$resp" | head -n1)
code=$(printf "%s" "$resp" | tail -n1)
[ "$code" = "200" ] || { echo "[FAIL] Expected 200, got $code"; echo "$body"; exit 1; }
ret_title=$(printf "%s" "$body" | jq -r .title)
ret_status=$(printf "%s" "$body" | jq -r .status)
[ "$ret_title" = "改題" ] || { echo "[FAIL] title not updated"; exit 1; }
[ "$ret_status" = "読了" ] || { echo "[FAIL] status not updated"; exit 1; }

echo "[PASS] PUT /books/{bookId} -> 200 with updated fields"
