#!/usr/bin/env sh
# 統合テスト: US5 削除フロー（作成→削除→404確認）
set -eu
API_BASE=${API_BASE:-$(cat .api_base_url 2>/dev/null || true)}
[ -n "${API_BASE:-}" ] || { echo "[ERROR] API_BASE not set and .api_base_url not found"; exit 1; }
which jq >/dev/null 2>&1 || { echo "[ERROR] jq is required"; exit 1; }

create=$(curl -s -X POST "$API_BASE/books" -H 'Content-Type: application/json' \
  -d '{"title":"消す対象","author":"著者","status":"未読"}')
bookId=$(printf "%s" "$create" | jq -r .bookId)

curl -s -X DELETE "$API_BASE/books/$bookId" >/dev/null

code=$(curl -s -o /dev/null -w "%{http_code}" "$API_BASE/books/$bookId")
[ "$code" = "404" ] || { echo "[FAIL] Expected 404 after delete, got $code"; exit 1; }

echo "[PASS] Delete flow OK: $bookId"
