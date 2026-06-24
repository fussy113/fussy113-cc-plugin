# guardrail

危険な操作と機密の漏えいを**フックで自動的に抑止する**プラグイン。
ユーザーの作業を止めすぎないよう、ブロックは最小限に絞り、シークレット検出は「確認(ask)」止まりにしています。
LLM 呼び出しは一切なく、トークンコストはゼロです。

## 構成

| フック | イベント | 役割 | 挙動 |
|---|---|---|---|
| `hooks/destructive-guard.sh` | PreToolUse (Bash) | 真に危険なコマンドのみ検出 | **ブロック**(exit 2、理由を Claude に差し戻し) |
| `hooks/secret-guard.sh` | PreToolUse (Write / Edit) | 書き込み内容のシークレット検出 | **確認を促す**(`permissionDecision: ask`、ブロックはしない) |

## ブロックする危険コマンド(destructive-guard)

誤検知を避けるため denylist は意図的に狭く保っています。

| # | 検出 | 代替 |
|---|---|---|
| 1 | `rm -rf /` / `rm -rf ~` / `rm -rf /*`(ルート・ホーム全体の削除) | 削除対象を具体パスで限定する(`rm -rf ~/.cache` 等のサブディレクトリは対象外) |
| 2 | `rm --no-preserve-root` | 使わない |
| 3 | `git push --force` / `-f` | `git push --force-with-lease`(こちらは許容) |
| 4 | `git --no-verify` | フックを通す |
| 5 | `git reset --hard` | `git stash` で退避してから |
| 6 | SQL の `DROP TABLE` / `DROP DATABASE` | 対象確認・バックアップ後に実行 |

## 検出するシークレット(secret-guard)

Write / Edit の書き込み内容に、以下の**高精度なパターン**が含まれると確認を促します(一般的すぎる形は誤検知防止のため対象外)。

- 秘密鍵ヘッダ(`-----BEGIN ... PRIVATE KEY-----`)
- AWS アクセスキー(`AKIA…`)、GitHub トークン(`ghp_` / `gho_` / `github_pat_…`)
- Slack(`xox…`)、Google API キー(`AIza…`)、Stripe(`sk_live_…`)、GitLab PAT(`glpat-…`)
- OpenAI / Anthropic 形式(`sk-…` / `sk-ant-…`)

> これはユーザーのグローバル方針「トークン・API キーをコードや設定に直書きしない/機密ファイルをそのまま出力しない」をシステムレベルで補強するものです。

## 設計上の注意

- フックは**作業を止めすぎない**ことを最優先にしています。ブロックは destructive のみ、シークレットは `ask`(ユーザーが許可/拒否を選ぶ)に留めます。
- 判定不能・`jq` 不在・対象外イベントは常に `exit 0` でフェイルオープンします(安全網であって厳格な境界ではありません)。
- `jq` があれば `tool_input` を厳密に解析します。無い場合は入力全体を簡易走査します。
- ルールが過剰だと感じたら、`destructive-guard.sh` の該当 `if` ブロックをコメントアウトすれば個別に無効化できます。

## 関連

- `tools-for-mac` の Stop/Notification 通知フックとは独立して動作し、干渉しません。
