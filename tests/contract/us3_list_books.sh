#!/usr/bin/env sh
# 契約テスト: US3 GET /books
set -eu
API_BASE=${API_BASE:-$(cat .api_base_url 2>/dev/null || true)}
[ -n "${API_BASE:-}" ] || { echo "[ERROR] API_BASE not set and .api_base_url not found"; exit 1; }
which jq >/dev/null 2>&1 || { echo "[ERROR] jq is required"; exit 1; }

resp=$(curl -s -w "\n%{http_code}" "$API_BASE/books")
body=$(printf "%s" "$resp" | head -n1)
code=$(printf "%s" "$resp" | tail -n1)
[ "$code" = "200" ] || { echo "[FAIL] Expected 200, got $code"; echo "$body"; exit 1; }
count=$(printf "%s" "$body" | jq -r .count)
items_len=$(printf "%s" "$body" | jq -r '.items | length')
[ "$count" = "$items_len" ] || { echo "[FAIL] count mismatch: $count vs $items_len"; exit 1; }

echo "[PASS] GET /books -> 200, items=$items_len"
