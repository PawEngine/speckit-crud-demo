#!/usr/bin/env sh
# 統合テスト: US1 作成→取得
set -eu
API_BASE=${API_BASE:-$(cat .api_base_url 2>/dev/null || true)}
[ -n "${API_BASE:-}" ] || { echo "[ERROR] API_BASE not set and .api_base_url not found"; exit 1; }
which jq >/dev/null 2>&1 || { echo "[ERROR] jq is required"; exit 1; }

create=$(curl -s -X POST "$API_BASE/books" -H 'Content-Type: application/json' \
  -d '{"title":"こころ","author":"夏目漱石","status":"未読"}')
bookId=$(printf "%s" "$create" | jq -r .bookId)
[ "$bookId" != "null" ] && [ -n "$bookId" ] || { echo "[FAIL] create missing bookId"; exit 1; }

get=$(curl -s "$API_BASE/books/$bookId")
retId=$(printf "%s" "$get" | jq -r .bookId)
[ "$retId" = "$bookId" ] || { echo "[FAIL] get mismatch: $retId != $bookId"; exit 1; }

echo "[PASS] Create and Get OK: $bookId"
