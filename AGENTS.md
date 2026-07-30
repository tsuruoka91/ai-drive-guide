# AI Drive Guide: 作業ガイド

このファイルは、このリポジトリで作業するAIエージェントと開発者向けの引き継ぎ情報です。利用者向けの起動手順は `README.md` を参照してください。

## 現在の状態

- Rails 8.0.5.1、Ruby 3.3.5、PostgreSQL 16を使用する。
- Hotwire は Turbo / Stimulus と importmap を使用する。Node.jsのビルド工程は追加しない。
- Docker Composeで開発する。Webアプリは `http://localhost:3000` で起動する。
- 現在は初期画面のみ。位置情報取得、ガイドAPI、OpenAI連携、音声読み上げは未実装。

## 実装上の方針

- 画面の操作はStimulusコントローラに置く。サーバー側のJSON応答はRailsのコントローラとサービスオブジェクトで扱う。
- APIキーをブラウザへ送らない。将来のOpenAI API呼び出しは必ずRailsバックエンドから行う。
- 位置情報は機微なデータとして扱う。必要になるまで永続化せず、ログにも緯度・経度を出力しない。
- Geolocation APIはHTTPS環境（開発時はlocalhost）で使う。位置取得は明示的なユーザー操作を起点にする。
- SpeechSynthesisは`ja-JP`を指定する。iPhone Safariで自動再生できない場合に備え、再読み上げ操作を提供する。
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
