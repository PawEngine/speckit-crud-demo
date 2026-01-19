## 実際に実行したプロンプトまとめ
このmdファイルは実際に"001-books-update-delete"ブランチで実行したプロンプトについて記録したものです。

### 1. /speckit.constitution プロンプト(憲法作成)
```
既存の書籍管理APIに、残りの機能である「更新 (Update)」と「削除 (Delete)」を追加します。 現在の仕様（spec.md）と実装コード（books_handler.py）をベースに、以下の機能を拡張してください。
追加機能:
PUT /books/{bookId}: 指定されたIDの書籍情報を更新する。タイトル、著者、ステータス（Status）の変更を可能にしてください。
DELETE /books/{bookId}: 指定されたIDの書籍データをDynamoDBから削除する。
要件:
既存の BooksTable (Partition Key: BookId) を継続して使用します。
API Gateway の既存のREST APIリソースに新しいメソッド（PUT, DELETE）を追加します。
Lambda関数（books_handler.py）を更新し、新しいアクション（update, delete）に対応させてください。
アウトプット:
Constitutionに従い、AWS CLIを用いたリソースの更新手順を含めてください。
更新・削除が正しく動作することを確認するための curl コマンドによるテスト手順を含めてください。
```

### 2./speckit.plan プロンプト(実装計画作成)

```
新しく追加された「Update/Delete」機能の仕様に基づき、既存のAWSリソースを拡張・更新するための段階的な実装計画を作成してください。
重視するポイント:
1. 既存環境との共存 (Incremental Updates):
    * すでに作成済みの DynamoDB テーブルや IAM ロール、API Gateway を最大限活用し、破壊的な変更を避けつつ必要な差分のみを適用すること。
2. 構成要素の分離と順序:
    * Step 1: バックエンド (Lambda) のロジック拡張: books_handler.py に PUT と DELETE の処理コードを追加する。
    * Step 2: Lambda 関数の更新: 更新したコードをデプロイ（update-function-code）する。
    * Step 3: API 公開 (API Gateway) の設定拡張: 既存のリソースに対し、PUT と DELETE メソッド、および Lambda 統合を追加設定する。
3. ファイル構成と差分管理:
    * 修正が必要な既存ファイル（books_handler.py 等）を明記し、追加で必要になる設定ファイルがあればそれもリストアップすること。
4. ロールバックの考慮:
    * 変更作業中に問題が発生した場合、元の（Create/Read のみの）状態に影響を与えないよう配慮して計画すること。
アウトプット: プロジェクト憲法（Constitution）に従い、すべて AWS CLI を用いた具体的なコマンド実行手順として計画を提示してください。
```