#!/usr/bin/env sh
# 契約テスト: US2 GET /books/{bookId}
set -eu
API_BASE=${API_BASE:-$(cat .api_base_url 2>/dev/null || true)}
[ -n "${API_BASE:-}" ] || { echo "[ERROR] API_BASE not set and .api_base_url not found"; exit 1; }
which jq >/dev/null 2>&1 || { echo "[ERROR] jq is required"; exit 1; }

# まず1件作成
body=$(curl -s -X POST "$API_BASE/books" -H 'Content-Type: application/json' \
  -d '{"title":"銀河鉄道の夜","author":"宮沢賢治","status":"未読"}')
bookId=$(printf "%s" "$body" | jq -r .bookId)

# 取得
resp=$(curl -s -w "\n%{http_code}" "$API_BASE/books/$bookId")
resp_body=$(printf "%s" "$resp" | head -n1)
code=$(printf "%s" "$resp" | tail -n1)
[ "$code" = "200" ] || { echo "[FAIL] Expected 200, got $code"; echo "$resp_body"; exit 1; }
ret=$(printf "%s" "$resp_body" | jq -r .bookId)
[ "$ret" = "$bookId" ] || { echo "[FAIL] bookId mismatch"; exit 1; }

echo "[PASS] GET /books/{bookId} -> 200"
