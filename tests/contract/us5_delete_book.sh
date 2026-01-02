#!/usr/bin/env sh
# 契約テスト: US5 DELETE /books/{bookId}
set -eu
API_BASE=${API_BASE:-$(cat .api_base_url 2>/dev/null || true)}
[ -n "${API_BASE:-}" ] || { echo "[ERROR] API_BASE not set and .api_base_url not found"; exit 1; }
which jq >/dev/null 2>&1 || { echo "[ERROR] jq is required"; exit 1; }

# まず1件作成
create=$(curl -s -X POST "$API_BASE/books" -H 'Content-Type: application/json' \
  -d '{"title":"消す本","author":"著者","status":"未読"}')
bookId=$(printf "%s" "$create" | jq -r .bookId)
[ -n "$bookId" ] && [ "$bookId" != "null" ] || { echo "[FAIL] create failed"; exit 1; }

# 削除
resp=$(curl -s -w "\n%{http_code}" -X DELETE "$API_BASE/books/$bookId")
body=$(printf "%s" "$resp" | head -n1)
code=$(printf "%s" "$resp" | tail -n1)
[ "$code" = "200" ] || { echo "[FAIL] Expected 200, got $code"; echo "$body"; exit 1; }
flag=$(printf "%s" "$body" | jq -r .deleted)
[ "$flag" = "true" ] || { echo "[FAIL] deleted flag false"; exit 1; }

# 404確認
code2=$(curl -s -o /dev/null -w "%{http_code}" "$API_BASE/books/$bookId")
[ "$code2" = "404" ] || { echo "[FAIL] Expected 404 after delete, got $code2"; exit 1; }

echo "[PASS] DELETE /books/{bookId} -> 200 then GET 404"
