# 技術構成とMVP設計

## 構成

| 領域 | 採用技術 | 役割 |
| --- | --- | --- |
| Web | Ruby 3.3.5 / Rails 8.0.5.1 | HTML表示、JSON API、将来のOpenAI API呼び出し |
| DB | PostgreSQL 16 | 将来必要になったデータのみを保存 |
| UI | Turbo / Stimulus / importmap | 画面操作とブラウザAPIの利用 |
| 実行環境 | Docker Compose | `web` と `db` のローカル開発環境 |
| 位置情報 | Geolocation API | スマートフォンの現在地を1回取得 |
| 音声 | SpeechSynthesis API | 日本語ガイドを端末上で読み上げ |

対象はAndroid Chromeを主とし、iPhone Safariでも使える構成にする。

## 現在の実装範囲

Railsの初期構成、PostgreSQL接続、Hotwire / Stimulusのセットアップに加え、固定ガイドを返す最初のMVPを実装済みである。座標はリクエスト処理だけに使い、保存しない。Railsのパラメータログからも除外している。

## 実装済みMVP

1. トップ画面の「ドライブ開始」ボタンで `navigator.geolocation.getCurrentPosition` を1回実行する。
2. 緯度・経度を同一オリジンのRailsエンドポイントへPOSTする。
3. Railsは座標の数値・範囲を検証し、固定のガイド文をJSONで返す。
4. Stimulusが文章を画面に表示し、`SpeechSynthesisUtterance`（`lang = "ja-JP"`）で読み上げる。
5. 位置情報の未対応・権限拒否・取得失敗、通信失敗、音声未対応・再生失敗を画面に表示する。

想定するAPIは以下である。

```http
POST /api/drive_guides
Content-Type: application/json

{"latitude":35.681236,"longitude":139.767125}
```

```json
{"guide":"安全運転で出発しましょう。周囲をよく確認してください。"}
```

初期段階ではモデルやマイグレーションを作らず、座標やガイド文を保存しない。

## 実装済みディレクトリ

```text
app/controllers/api/drive_guides_controller.rb
app/javascript/controllers/drive_guide_controller.js
app/services/drive_guide_generator.rb
test/controllers/api/drive_guides_controller_test.rb
```

固定文言を返す `DriveGuideGenerator` を先に作り、後のOpenAI連携ではサービス実装だけを差し替えられるようにする。

## 次のフェーズ

OpenAI API連携では、`DriveGuideGenerator` の実装を差し替える。APIキーはRails Credentialsまたはデプロイ環境の環境変数で管理し、座標をそのまま送る必要があるかを最小化してから導入する。

## セキュリティとプライバシー

- Geolocation APIはHTTPSでのみ利用する。本番では必ずTLSを終端する。
- 位置情報の利用目的を画面に示し、ボタンを押した時だけ取得する。
- 座標をリクエストログ、例外通知、分析ツールへ送らない。
- CSRF保護を有効に保つ。同一オリジンで運用するため、MVPでCORS設定は不要。
- OpenAI APIキーはRails Credentialsまたはデプロイ環境の環境変数にだけ保存する。
- OpenAI連携時にも、送信する地点情報は用途に必要な最小限にする。

## モバイル音声の注意

音声再生はユーザー操作が契機であることを求めるブラウザがある。特にiPhone Safariでは、位置情報・通信後の自動読み上げが失敗する可能性を考慮し、同じガイドを再生する明示的なボタンを用意する。特定の音声名には依存せず、端末の日本語既定音声を利用する。
