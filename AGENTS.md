# AI Drive Guide: 作業ガイド

このファイルは、このリポジトリで作業するAIエージェントと開発者向けの引き継ぎ情報です。利用者向けの起動手順は `README.md` を参照してください。

## 現在の状態

- Rails 8.0.5.1、Ruby 3.3.5、PostgreSQL 16を使用する。
- Hotwire は Turbo / Stimulus と importmap を使用する。Node.jsのビルド工程は追加しない。
- Docker Composeで開発する。Webアプリは `http://localhost:3000` で起動する。
- 固定文言を返す最初のMVPは実装済み。位置情報取得、Rails API、画面表示、SpeechSynthesisによる読み上げを含む。
- OpenAI API連携は実装済み。`OPENAI_API_KEY` が未設定の場合だけ固定ガイドへフォールバックする。
- 逆ジオコーディングはOpenStreetMap Nominatimを使う。公開サービスの上限（アプリ全体で毎秒1回以下）、識別用User-Agent、画面上の帰属表示を維持する。高トラフィック時は別プロバイダまたは専用インスタンスへ切り替える。
- 観光ガイド用の近隣スポットはOpenStreetMap Overpass APIから取得する。レスポンスに含まれた名称だけをOpenAIへ渡し、未確認の歴史・営業情報・交通状況を生成させない。
- 近隣スポットは公開APIへの重複アクセスを抑えるため、丸めた座標をキーにプロセス内メモリで5分だけキャッシュする。DB・ファイル・ログへの位置情報保存はしない。
- OSMに日本語Wikipedia参照があるスポットだけ、Wikipediaの冒頭要約を最大1件取得する。要約外の歴史的事実を生成させず、UIのWikipedia帰属表示を維持する。
- 位置情報の永続化、走行履歴は未実装。
- ガイドAPIは同一IPから1分間に3回まで（プロセス内メモリ）に制限する。複数プロセス・複数コンテナへ拡張する前に共有ストア方式へ置き換える。
- 開発環境だけでは飯塚の主な観光地を選ぶ地図用プルダウンが表示される。選択時は地図を移動し、「ドライブ開始」は選択地点を使う。本番用画面やAPIへテスト地点の分岐を持ち込まない。
- 開発環境ではデバッグのため、ブラウザの30秒通信タイムアウトとガイドAPIのIPレート制限を無効化する。本番環境では必ず有効にする。

## 実装上の方針

- 画面の操作はStimulusコントローラに置く。サーバー側のJSON応答はRailsのコントローラとサービスオブジェクトで扱う。
- APIキーをブラウザへ送らない。将来のOpenAI API呼び出しは必ずRailsバックエンドから行う。
- 位置情報は機微なデータとして扱う。必要になるまで永続化せず、ログにも緯度・経度を出力しない。
- OpenAI呼び出しにはアプリ独自の自動再試行を加えない。応答断での二重課金を避けるため、利用者の明示的な再操作で再試行する。
- Geolocation APIはHTTPS環境（開発時はlocalhost）で使う。位置取得は明示的なユーザー操作を起点にする。
- SpeechSynthesisは`ja-JP`を指定する。iPhone Safariで自動再生できない場合に備え、再読み上げ操作を提供する。
- SpeechSynthesisには、OpenAIが生成した漢字を含まない`speech_text`だけを渡す。画面表示用の`guide`とは混在させない。
- Google Maps JavaScript API用の`GOOGLE_MAPS_API_KEY`はブラウザで使用する専用キーにする。OpenAIキーと共有せず、HTTPリファラーとMaps JavaScript APIだけに制限する。
- 変更は最小限にし、MVP外の認証・履歴・バックグラウンド位置追跡は追加しない。

## 作業時のコマンド

```bash
# 起動
docker compose up --build

# テスト
docker compose run --rm web ./bin/rails test

# Railsルートの確認
docker compose run --rm web ./bin/rails routes

# 停止（DBデータは保持する）
docker compose down
```

Dockerを起動済みなら、テストは次でも実行できます。

```bash
docker compose exec web ./bin/rails test
```

## 機密情報とGit

- `.env`、`config/master.key`、`config/credentials/*.key` はコミットしない。
- 新しい環境変数は `.env.example` にキー名と安全な説明だけを追加する。実際の秘密値は書かない。
- 変更後は少なくともRailsテストを実行する。画面変更時は `http://localhost:3000` の表示も確認する。
- 依存関係を変更したら `Gemfile.lock` もコミットする。

詳細な構成と次のMVP実装は `docs/architecture.md` を参照してください。
