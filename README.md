# AI Drive Guide

スマートフォンの位置情報を基に音声ガイドを提供する Rails アプリです。おおよその現在地をきっかけに、OpenAIがラジオ番組風の創作ガイドを生成します。

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

## Google Mapsの設定

現在地を地図で表示するには、Google Cloudで **Maps JavaScript API** を有効にし、ブラウザ用のAPIキーを作成して `.env` に設定します。

```bash
GOOGLE_MAPS_API_KEY=your_google_maps_api_key_here
```

このキーはMaps JavaScript APIをブラウザから読み込むため、画面へ送信されます。Google Cloudでは、このアプリ専用キーにして、アプリケーション制限をHTTPリファラー（開発時は `http://localhost:3000/*`、本番は本番ドメイン）に、API制限をMaps JavaScript APIだけに設定してください。

開発環境では、地図の初期位置を九州工業大学飯塚キャンパスに設定しています。飯塚の主な観光地をプルダウンから選択すると、Googleマップがその地点へ移動します。開発環境の「ドライブ開始」は、選択中の観光地を座標としてガイド取得・読み上げを実行します。実GPS位置の変更や位置情報の保存は行いません。

## ガイド生成

Railsは小数第3位に丸めた現在地の座標だけをOpenAIへ渡し、ラジオ番組風の創作ガイドを生成します。実在の施設、歴史、営業情報、交通状況の正確さを保証する用途ではありません。OpenAIには画面表示用の日本語と、漢字を使わない読み上げ専用文をJSON形式で生成させ、ブラウザは後者を読み上げます。DBやファイルへ位置情報を保存しません。本番環境のガイドAPIは同一IPアドレスから1分間に3回までに制限し、ブラウザは30秒で通信を打ち切ります。開発環境ではデバッグを妨げないよう、これら2つの制限を適用しません。OpenAI呼び出しは二重課金を避けるためアプリ側で自動再試行せず、失敗時は利用者が再操作します。小規模なMVP用途を超える場合は、共有ストア対応のレート制限へ移行してください。

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
