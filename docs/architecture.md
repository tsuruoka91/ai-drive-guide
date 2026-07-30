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

開発環境では、トップ画面に飯塚の観光地を選ぶ地図用プルダウンを表示する。選択時はGoogleマップをその地点へ移動する。開発環境の「ドライブ開始」は選択中の観光地を使ってガイドAPI・音声読み上げを実行し、Geolocation APIは使わない。本番環境にはこのUIを表示しない。

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

## OpenAI API連携

`DriveGuideGenerator` はOpenAIのResponses APIとStructured Outputsを利用する。APIキーは `OPENAI_API_KEY` としてRailsコンテナだけへ渡し、ブラウザへ送らない。既定モデルは低遅延用途に `gpt-5.6-luna` を使い、`OPENAI_MODEL` で変更できる。応答は `display_text`（漢字混じりの画面表示）と `speech_text`（漢字を含まない読み上げ用）の2項目とし、ブラウザのSpeechSynthesisには後者だけを渡す。Railsは漢字を含まない `display_text`、または漢字を含む `speech_text` をエラーとして扱う。

## 地図表示

`drive_guide_controller.js` は現在地を取得した後、Google Maps JavaScript APIを遅延読み込みして地図の中心と「現在地」マーカーを更新する。開発環境では九州工業大学飯塚キャンパス（緯度33.65409392、経度130.67159183）を初期位置として表示する。開発用の観光地プルダウンは、選択地点へ地図とマーカーを移動する。開発環境の「ドライブ開始」は選択中の観光地を通常のガイドAPIへ渡し、Geolocation APIを使わない。GPS位置の変更や座標の保存も行わない。`GOOGLE_MAPS_API_KEY` はブラウザで利用するため公開されるが、OpenAIキーとは別の専用キーとし、HTTPリファラーとMaps JavaScript APIだけに制限する。未設定または読み込み失敗時も、ガイド取得・読み上げは継続する。

送信する座標は小数第3位へ丸める。座標をそのまま保存せず、ログにも出力しない。APIキー未設定時はローカル確認用に固定ガイドを返すが、本番では必ずAPIキーを設定する。

## 創作ガイドの生成

`DriveGuideGenerator` は小数第3位に丸めた現在地の座標だけをOpenAIへ渡し、ラジオ番組風の創作ガイドを生成する。実在の施設、歴史、営業情報、交通状況の正確さは保証しない。具体的な運転操作の指示や緊急情報のように受け取られる内容は避ける。座標はDB、ファイル、ログへ保存しない。

`DriveGuideRequestLimiter` は座標を保存せず、IPアドレスをSHA-256化したキーだけをプロセス内メモリへ一時保持して、本番環境で同一IPからのガイド取得を1分間に3回へ制限する。Pumaの複数プロセス・複数コンテナに拡張する際は、Redisなどの共有ストアを使うレート制限に置き換える。ブラウザはリクエスト中の開始操作を無効化し、本番環境では30秒で通信を打ち切る。開発環境では、GPSシミュレーションを含むデバッグのために両方の制限を無効化する。OpenAI呼び出しは、応答が失われた場合の二重課金を避けるためアプリ側では自動再試行しない。

## セキュリティとプライバシー

- Geolocation APIはHTTPSでのみ利用する。本番では必ずTLSを終端する。
- 位置情報の利用目的を画面に示し、ボタンを押した時だけ取得する。
- 座標をリクエストログ、例外通知、分析ツールへ送らない。
- CSRF保護を有効に保つ。同一オリジンで運用するため、MVPでCORS設定は不要。
- OpenAI APIキーはRails Credentialsまたはデプロイ環境の環境変数にだけ保存する。
- OpenAI連携時にも、送信する地点情報は用途に必要な最小限にする。

## モバイル音声の注意

音声再生はユーザー操作が契機であることを求めるブラウザがある。特にiPhone Safariでは、位置情報・通信後の自動読み上げが失敗する可能性を考慮し、同じガイドを再生する明示的なボタンを用意する。特定の音声名には依存せず、端末の日本語既定音声を利用する。
