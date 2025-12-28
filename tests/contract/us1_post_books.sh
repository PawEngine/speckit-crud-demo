#!/usr/bin/env sh
# 契約テスト: US1 POST /books
set -eu
API_BASE=${API_BASE:-$(cat .api_base_url 2>/dev/null || true)}
[ -n "${API_BASE:-}" ] || { echo "[ERROR] API_BASE not set and .api_base_url not found"; exit 1; }

which jq >/dev/null 2>&1 || { echo "[ERROR] jq is required"; exit 1; }

resp=$(curl -s -w "\n%{http_code}" -X POST "$API_BASE/books" \
  -H 'Content-Type: application/json' \
  -d '{"title":"吾輩は猫である","author":"夏目漱石","publishedDate":"1905-01-01","status":"未読"}')
body=$(printf "%s" "$resp" | head -n1)
code=$(printf "%s" "$resp" | tail -n1)
[ "$code" = "201" ] || { echo "[FAIL] Expected 201, got $code"; echo "$body"; exit 1; }
bookId=$(printf "%s" "$body" | jq -r .bookId)
[ "$bookId" != "null" ] && [ -n "$bookId" ] || { echo "[FAIL] bookId missing"; exit 1; }
echo "[PASS] POST /books -> 201, bookId=$bookId"
