#!/usr/bin/env sh
# 共通の環境変数設定スクリプト（AWS CLI 前提）
set -eu

# 必要に応じて上書きしてください
export AWS_REGION="ap-northeast-1"   # 東京リージョン
export STAGE="v1"
export TABLE_NAME="BooksTable"
export FUNCTION_NAME="BooksApiFunction"
export API_NAME="BooksApi"

# 実行アカウントIDを取得
export ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
