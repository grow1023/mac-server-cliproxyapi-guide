# Mac Server CLIProxyAPI Guide

常時稼働の Mac mini や Mac Studio で CLIProxyAPI を動かし、ほかの端末やサービスから 1 つのプライベートなアドレスで AI モデル API を使うための手順です。インストールから設定、ログイン、常駐化、リモート接続、クライアント設定までを扱います。

[English](README.md) | [한국어](README.ko.md) | **日本語** | [简体中文](README.zh.md)

![Mac Server CLIProxyAPI Guide: 説明用の図であり、実際のアプリ画面ではありません](assets/ja/hero.png)

0.1.0 · MIT

## 使う理由

| | |
| --- | --- |
| すべての端末で使う 1 台のサーバー | AI アカウントへのログインはサーバーで 1 回だけ行います。その後、Claude Code、Codex、OpenAI SDK のスクリプト、OpenAI 互換サービスが、それぞれのクライアントキーで同じアドレスに接続します。 |
| インターネット公開ではなくプライベート接続 | 同じ LAN、Tailscale 直接接続、HTTPS で公開する Tailscale Serve、SSH トンネルの 4 つの接続方法を比較します。それぞれに必要なバインドアドレスを説明し、ルーターのポートフォワーディングと Tailscale Funnel は使わないよう案内します。 |
| どのクライアントからでも確認可能 | scripts/check-proxy.sh がヘルスエンドポイントを確認し、キーのないリクエストが拒否されることを確かめ、キーで見えるモデル数を数えます。キーは出力しません。 |

## クイックスタート

Homebrew を入れた Apple Silicon の Mac mini または Mac Studio と、CLIProxyAPI が対応するアカウントが必要です。サービスを起動する前に、$(brew --prefix)/etc/cliproxyapi.conf のサンプルキーを自分で作ったクライアントキーに置き換えます（docs/guide.md 5 章）。最後のコマンドはこのリポジトリのクローンで実行します。

```text
brew install cliproxyapi
cliproxyapi -claude-login
brew services start cliproxyapi
PROXY_URL=http://127.0.0.1:8317 PROXY_KEY=<client-key> ./scripts/check-proxy.sh
```

チェックはヘルスエンドポイント、キーなしリクエストの拒否、モデル一覧について PASS を表示し、最後に ALL CHECKS PASSED を表示します。

## 仕組み

ガイドはサーバーを準備する順番に沿っています。リモート接続はステップ 3 で選ぶオプションで、同じ LAN 内では追加のネットワークツールは不要です。

![仕組み: 説明用の図であり、実際のアプリ画面ではありません](assets/ja/architecture.png)

### Mac の準備と設定

システムのスリープを無効にし、Homebrew で cliproxyapi をインストールして、自分のクライアントキーを入れた小さな v8 設定を書きます。

### ログインとサービス起動

アカウントごとに -login フラグでログインし、brew services で起動して、接続方法として LAN、Tailscale、SSH トンネルのいずれかを選びます。

### クライアントの接続

Claude Code、Codex、SDK スクリプト、OpenAI 互換サービスにプロキシのアドレスとクライアントキーを設定し、モデル名は /v1/models から選びます。

## 活用例

### 自宅の AI ゲートウェイ

リビングの Mac mini が、同じ LAN のノート PC とデスクトップに API を提供します。

### 外出先でも自分の端末だけ

Tailscale を使えば、インターネットにポートを開けずに外出先のノート PC からサーバーに接続できます。

### 自動化ツールの接続

n8n、Open WebUI、自作スクリプトが OpenAI 互換の Base URL と専用キーで接続します。

![すべての端末で使う 1 台のサーバー: 説明用の図であり、実際のアプリ画面ではありません](assets/ja/gallery-1.png)

![インターネット公開ではなくプライベート接続: 説明用の図であり、実際のアプリ画面ではありません](assets/ja/gallery-2.png)

![どのクライアントからでも確認可能: 説明用の図であり、実際のアプリ画面ではありません](assets/ja/gallery-3.png)

## 制約とプライバシー

- コマンドと設定キーは CLIProxyAPI v8.0.76 のソースと Homebrew formula で確認しました。このガイドのために全手順を実機サーバーで再実行してはいません。

- CLIProxyAPI は頻繁に変わります。ほかのバージョンではフラグ、キー名、Codex の設定形式が異なる場合があります。

- サブスクリプションアカウントをプロキシ経由で使う場合は、各提供元の規約に従う必要があります。ほかの人とアカウントを共有すると規約違反になる場合があります。

- サーバーは OAuth トークンを ~/.cli-proxy-api に保存します。このフォルダーやクライアントキーを持つ人は、あなたのアカウントの利用枠を使えます。

## 検証状況

- **実行確認済み**: tests/run.sh をローカルで実行しました。shellcheck、ローカルスタブに対する check-proxy.sh（正常、誤ったキー、キーなしで通過、モデルなし、サーバー停止）、設定例、文書リンク、英語・韓国語の一致、上流フラグ一覧、プライバシー検査がすべて合格しました。
- **コード確認済み**: ログインフラグ、キーヘッダー、API パス、デフォルトポート、Homebrew の設定パスは、上流コミット 7df5607 のソースと formula で確認しました。
- **文書に記載**: 未検証：実アカウントでの CLIProxyAPI 実行、リモート接続、各クライアント連携。

## 次のステップ

詳しい手順は docs/guide.md（英語）または docs/guide.ko.md（韓国語）を読み、接続した各クライアントで scripts/check-proxy.sh を実行してください。

<details>
<summary>根拠一覧</summary>

[JSON](docs/showcase/sources.json)

- `ev-scope`: `docs/guide.md`, L7–L7 (文書に記載)
- `ev-architecture`: `docs/guide.md`, L25–L46 (文書に記載)
- `ev-awake`: `docs/guide.md`, L58–L72 (文書に記載)
- `ev-install`: `docs/guide.md`, L74–L101 (コード確認済み)
- `ev-config`: `docs/guide.md`, L103–L142 (コード確認済み)
- `ev-login`: `docs/guide.md`, L144–L172 (コード確認済み)
- `ev-service`: `docs/guide.md`, L174–L192 (コード確認済み)
- `ev-check`: `docs/guide.md`, L194–L210 (文書に記載)
- `ev-access`: `docs/guide.md`, L212–L224 (文書に記載)
- `ev-clients`: `docs/guide.md`, L226–L286 (文書に記載)
- `ev-security`: `docs/guide.md`, L288–L295 (文書に記載)
- `ev-example-config`: `examples/config.server.yaml`, L1–L29 (コード確認済み)
- `ev-check-script`: `scripts/check-proxy.sh`, L1–L52 (コード確認済み)
- `ev-tests`: `tests/run.sh`, L1–L134 (実行確認済み)

- `one-server` → `ev-architecture`, `ev-clients`
- `private-access` → `ev-access`, `ev-security`
- `checkable` → `ev-check-script`, `ev-check`
- `flow-install` → `ev-awake`, `ev-install`, `ev-config`, `ev-example-config`
- `flow-run` → `ev-login`, `ev-service`, `ev-access`
- `flow-connect` → `ev-clients`, `ev-check`
- `home-lab` → `ev-access`
- `away` → `ev-access`, `ev-security`
- `automation` → `ev-clients`
- `not-rerun` → `ev-scope`
- `versions` → `ev-scope`, `ev-clients`
- `terms` → `ev-security`
- `tokens` → `ev-config`, `ev-security`
- `repo-tests` → `ev-tests`
- `source-checked` → `ev-install`, `ev-login`, `ev-config`
- `live-server` → `ev-scope`
- `quickstart` → `ev-install`, `ev-login`, `ev-service`, `ev-check-script`

</details>
