# AI Drive Guide

スマートフォンの位置情報を基に短い音声ガイドを提供する Rails アプリです。現在は Docker Compose、PostgreSQL、Hotwire / Stimulus を備えた初期構成のみを含みます。ドライブガイド機能はまだ実装していません。

## 技術構成

- Ruby 3.3.5 / Rails 8.0.5.1
- PostgreSQL 16
- Hotwire（Turbo / Stimulus、importmap）
- Docker Compose

## 起動方法

1. 環境変数ファイルを作成します。

   ```bash
   cp .env.example .env
   ```

   `.env` はGit管理されません。ローカル開発用に `POSTGRES_PASSWORD` を変更してください。

2. コンテナをビルドして起動します。

   ```bash
   docker compose up --build
   ```

3. ブラウザで [http://localhost:3000](http://localhost:3000) を開きます。

初回起動時、Webコンテナは `db:prepare` を実行してデータベースを準備します。

停止するには `Ctrl+C` の後に以下を実行します。

```bash
docker compose down
```

データベースを含めて削除する場合だけ、以下を実行してください。

```bash
docker compose down -v
```

## 確認コマンド

```bash
docker compose run --rm web ./bin/rails test
```

This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

* Ruby version

* System dependencies

* Configuration

* Database creation

* Database initialization

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ...
