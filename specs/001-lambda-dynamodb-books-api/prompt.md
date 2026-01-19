## 実際に実行したプロンプトまとめ
このmdファイルは実際に"001-lambda-dynamodb-books-api"ブランチで実行したプロンプトについて記録したものです。

### 1. /speckit.constitution プロンプト(憲法作成)
```
# プロジェクト憲法 (Project Constitution)

このドキュメントは、本プロジェクトにおけるAIエージェント（あなた）の行動指針と絶対的なルールを定義したものです。

## 1. 技術スタックと絶対的制約 (Tech Stack & Constraints)
* **クラウドプロバイダー**: AWS (Amazon Web Services)
* **インフラ構築手段**: **AWS CLI コマンドのみを使用すること**。
    * **禁止事項**: Terraform, CloudFormation, AWS CDK, AWSマネジメントコンソール（GUI）の手順提案。
    * **理由**: ユーザーはAWS CLIによる操作習得を目的としているため。
* **アーキテクチャ**: サーバーレス構成
    * Compute: AWS Lambda (Runtime: Python 3.10以上 または Node.js 20以上)
    * Database: Amazon DynamoDB
    * API: Amazon API Gateway (REST API または HTTP API)
* **認証**: 今回は実装しない（パブリックアクセスとする）。

## 2. 開発プロセスと行動指針 (Development Process)
* **CLIファースト**:
    * いかなる実装を行う前にも、まず「必要なAWSリソースを作成するためのAWS CLIコマンド」を提示すること。
    * コマンドは、そのままターミナルに貼り付けて実行可能な形式（シェルスクリプト形式など）で提供すること。
    * 各コマンドには、何をしているかを示す日本語のコメント（`#`）を必ず付与すること。
* **冪等性とクリーンアップ**:
    * 作成だけでなく、実験が終わった後にリソースを削除するためのコマンド（`delete-function`, `delete-table` 等）も考慮すること。
* **コード品質**:
    * 作成するLambda関数のコードには、処理内容を説明する日本語のコメントを丁寧に記述すること。
    * エラーハンドリング（DynamoDB接続エラー等）を省略せずに実装すること。

## 3. ドキュメンテーションと対話 (Documentation)
* **初心者への配慮**:
    * あなたは「技術ブログの執筆を支援するパートナー」です。専門用語を使う際は、簡潔な補足を加えるか、なぜその技術選定をしたのか理由を述べること。
    * 仕様書（spec.md）や計画書（plan.md）は、誰が読んでも理解できる明確な日本語で記述すること。
```

### 2. /speckit.specify　プロンプト(仕様作成)
```
サーバーレス構成（Lambda + DynamoDB）による書籍管理APIを作成します。
今回はまず「登録(Create)」と「参照(Read)」の機能のみを実装します。
後ほどUpdateやDelteなどの機能追加をする予定です。
拡張ができるような設計で実装を進めてください。

**要件**:
- DynamoDBのテーブル名は `BooksTable` とし、Partition Keyは `BookId` とします。
- API GatewayはREST APIとして構築します。

**機能**:
1. `POST /books`: 書籍（タイトル、著者、出版日）をJSONで受け取り、DBに保存する。
2. `GET /books/{bookId}`: 指定されたIDの書籍情報を返す。

3. **データモデル (Book)**:
   - ID (自動生成のUUID)
   - Title (書籍名)
   - Author (著者名)
   - Status (未読/読了)

4. **必要なAPI機能**:
   - **Create**: 新しい書籍データを登録する。
   - **Read (All)**: 登録されている書籍の一覧を取得する。
   - **Read (One)**: IDを指定して特定の書籍情報を取得する。

Constitutionに従い、AWS CLIでの構築を前提とした仕様と、curlコマンドでのテスト方法を含めてください。
```

### 3. /speckit.plan プロンプト(実装計画作成)
```
仕様書に基づき、AWS CLIを用いてリソースを構築するための段階的な実装計画を作成してください。

**重視するポイント**:
1. **依存関係の順守**: IAMロールやポリシーなど、先に作成が必要なリソースを明確にし、正しい順序で計画すること。
2. **構成要素の分離**:
    - Step 1: データベース (DynamoDB) の構築
    - Step 2: 権限周り (IAM Role & Policy) の設定
    - Step 3: バックエンド (Lambda) の実装とデプロイ
    - Step 4: API公開 (API Gateway) の設定
3. **ファイル構成**: 各ステップで必要なファイル（IAMポリシーのJSONファイル、LambdaのPythonコード等）を明記すること。
```
