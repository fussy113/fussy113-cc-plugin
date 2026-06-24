---
name: ccusage
argument-hint: "[today|week|month|session (optional)]"
description: ccusage を使って Claude Code のトークン消費とコストを表示する。日次/週次/月次/セッション別の使用量を確認したいときに使う
allowed-tools: Bash(npx ccusage:*)
---

# /ccusage — トークン消費・コストの可視化

[ccusage](https://github.com/ryoppippi/ccusage) を呼び出し、Claude Code のトークン消費とコストを集計表示します。
ローカルの使用ログを集計するだけで、外部送信はありません。

`$ARGUMENTS` で期間を指定できます(省略時は日次)。

## 期間とサブコマンドの対応

| 引数 | ccusage サブコマンド | 内容 |
|---|---|---|
| (なし) / `today` / `daily` | `daily` | 日次のトークン/コスト集計 |
| `week` / `weekly` | `weekly` | 週次集計 |
| `month` / `monthly` | `monthly` | 月次集計 |
| `session` | `session` | セッション別集計 |

## 実行手順

1. **引数の解釈**: `$ARGUMENTS` を上表に従ってサブコマンドへマッピングする。未知の値なら `daily` にフォールバックし、その旨を伝える。
2. **実行**: 対応するサブコマンドを実行する。
   ```bash
   npx ccusage@latest daily
   ```
   (`week` 指定なら `npx ccusage@latest weekly`、以下同様)
3. **結果の提示**: 出力をそのまま見せたうえで、要点(当日/当月の概算コスト、消費の大きいモデルや日)を1〜2行で要約する。
4. **エラー時**: 下記エラーハンドリングに従う。

## エラーハンドリング

- `npx` が見つからない → 「Node.js/npm 環境が必要です。`mise` プラグインや Node のインストールを確認してください」と案内。
- 初回実行でダウンロードに失敗(ネットワーク不通) → 「ccusage の取得にはネットワークアクセスが必要です」と伝える。
- 使用ログが見つからない → ccusage が参照するログパス(既定では `~/.claude` 配下)に履歴があるか確認するよう案内。

## 使用例

```bash
/ccusage
/ccusage month
/ccusage session
```

## 関連

- 事前にタスク規模で effort/モデルを最適化するには `effort-router` を参照。実測(ccusage)と見積もり(effort-router)を合わせてトークン効率を改善する。
