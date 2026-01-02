#!/usr/bin/env sh
# IAM ロール/ポリシー作成（冪等・最小権限）
set -eu
. "$(dirname "$0")/00_env.sh"
TRUST="iam/policies/lambda-trust-policy.json"

# ロール作成（存在チェック）
if aws iam get-role --role-name BooksApiRole >/dev/null 2>&1; then
  echo "[INFO] Role 'BooksApiRole' already exists."
else
  echo "[INFO] Creating role 'BooksApiRole'..."
  aws iam create-role --role-name BooksApiRole --assume-role-policy-document file://"$TRUST"
fi

# ポリシー（テーブルARNを動的に埋め込み、存在時は新バージョンを既定化）
TABLE_ARN="arn:aws:dynamodb:${AWS_REGION}:${ACCOUNT_ID}:table/${TABLE_NAME}"
mkdir -p .build
cat > .build/lambda-dynamodb-policy.json <<JSON
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["dynamodb:PutItem","dynamodb:GetItem","dynamodb:Scan","dynamodb:DeleteItem"],
      "Resource": "${TABLE_ARN}"
    },
    {
      "Effect": "Allow",
      "Action": ["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"],
      "Resource": "*"
    }
  ]
}
JSON

POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/BooksApiDynamoDBPolicy"
if aws iam get-policy --policy-arn "$POLICY_ARN" >/dev/null 2>&1; then
  echo "[INFO] Updating policy version for 'BooksApiDynamoDBPolicy'..."
  aws iam create-policy-version \
    --policy-arn "$POLICY_ARN" \
    --policy-document file://.build/lambda-dynamodb-policy.json \
    --set-as-default >/dev/null
else
  echo "[INFO] Creating policy 'BooksApiDynamoDBPolicy'..."
  aws iam create-policy --policy-name BooksApiDynamoDBPolicy --policy-document file://.build/lambda-dynamodb-policy.json >/dev/null
fi

# アタッチ（重複OK）
aws iam attach-role-policy --role-name BooksApiRole --policy-arn "$POLICY_ARN" 2>/dev/null || true

# 有効化待ちとARN取得
sleep 10
ROLE_ARN=$(aws iam get-role --role-name BooksApiRole --query 'Role.Arn' --output text)
echo "$ROLE_ARN" > .role_arn
echo "[OK] Role ARN saved to .role_arn"
