# AI Drive Guide

スマートフォンの位置情報を基に短い音声ガイドを提供する Rails アプリです。現在は固定文言を返す最初のMVPを実装しており、OpenAI API連携はまだ行いません。

## 技術構成

- Ruby 3.3.5 / Rails 8.0.5.1
- PostgreSQL 16
- Hotwire（Turbo / Stimulus、importmap）
- Docker Compose

## 現在のMVP

- 「ドライブ開始」操作で現在地を1回取得
- Rails APIへ座標をPOSTし、固定の日本語ガイドを取得
- ガイドを画面に表示して、ブラウザのSpeechSynthesis APIで読み上げ
- 位置情報・通信・音声読み上げのエラーを画面に表示

位置情報は保存せず、緯度・経度はRailsのパラメータログから除外しています。

開発環境では、GPSのないPCでも確認できる「現在地シミュレーション」を表示します。選択した地点で、ガイド取得と音声読み上げを試せます。本番環境には表示されません。

## OpenAI APIの設定

OpenAI APIを使うには、`.env` にAPIキーを設定してDocker Composeを再起動します。

```bash
OPENAI_API_KEY=your_api_key_here
OPENAI_MODEL=gpt-5.6-luna
```

APIキーはブラウザへ送信せず、Railsバックエンドだけで利用します。未設定時は、開発・動作確認用に固定ガイドを返します。

## 地点情報

RailsはOpenStreetMap Nominatimの逆ジオコーディングとOverpass APIを使い、道路・地域名と近隣の名称付きスポットを取得してOpenAIへ渡します。OSMに日本語Wikipediaの参照があるスポットでは、Wikipediaの冒頭要約も1件だけ取得し、歴史・概要の案内に利用します。近隣スポットはプロセス内メモリに5分だけキャッシュし、DBやファイルへ位置情報を保存しません。公開サービスを使うため、アプリ内で各サービスを毎秒1回以下に制限し、OpenStreetMapとWikipediaの帰属を画面に表示しています。小規模なMVP用途を超える場合は、専用インスタンスまたは商用の地図サービスへ切り替えてください。

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
