#!/usr/bin/env sh
# 統合テスト: US4 更新フロー（作成→更新→取得確認）
set -eu
API_BASE=${API_BASE:-$(cat .api_base_url 2>/dev/null || true)}
[ -n "${API_BASE:-}" ] || { echo "[ERROR] API_BASE not set and .api_base_url not found"; exit 1; }
which jq >/dev/null 2>&1 || { echo "[ERROR] jq is required"; exit 1; }

create=$(curl -s -X POST "$API_BASE/books" -H 'Content-Type: application/json' \
  -d '{"title":"はじめ","author":"著者","status":"未読"}')
bookId=$(printf "%s" "$create" | jq -r .bookId)

curl -s -X PUT "$API_BASE/books/$bookId" -H 'Content-Type: application/json' \
  -d '{"title":"あと","status":"読了"}' >/dev/null

get=$(curl -s "$API_BASE/books/$bookId")
ret_title=$(printf "%s" "$get" | jq -r .title)
ret_status=$(printf "%s" "$get" | jq -r .status)
[ "$ret_title" = "あと" ] || { echo "[FAIL] title not updated"; exit 1; }
[ "$ret_status" = "読了" ] || { echo "[FAIL] status not updated"; exit 1; }

echo "[PASS] Update flow OK: $bookId"
