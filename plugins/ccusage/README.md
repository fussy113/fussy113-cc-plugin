# ccusage

[ccusage](https://github.com/ryoppippi/ccusage) を使って Claude Code の**トークン消費とコストを可視化**するプラグイン。
`npx` で即実行できるため、依存をインストールせずに使えます。

## 構成

| スキル | 役割 |
|---|---|
| `/ccusage` | 日次/週次/月次/セッション別のトークン消費とコストをターミナルに表示する |

## 使い方

```bash
# 既定(日次)サマリ
/ccusage

# 期間を指定
/ccusage today
/ccusage week
/ccusage month
/ccusage session
```

内部的には `npx ccusage@latest <subcommand>` を呼び出し、ローカルの Claude Code 使用ログ(`~/.claude` 等)を集計します。
データはローカルで集計され、外部送信はありません。

## 設計思想

- **計測なくして効率化なし**。`effort-router` で「どの effort/モデルを使うか」を判断する一方、ccusage は「実際にいくら使ったか」を可視化します。両者をセットで使うとトークン効率の PDCA が回ります。
- `npx` 実行で本リポジトリに依存を増やしません。初回はダウンロードのためネットワークアクセスが必要です。

## 関連

- effort/モデルをタスク規模で事前に最適化するには `effort-router` プラグインを参照。
- セッションの作業記録は `self-improve` プラグインの journal が担います(git 差分の記録)。ccusage は「トークンコスト」を補完します。

## 補足

将来的に、`self-improve` の Stop フックと統合して当日コストを `~/.claude/session-journal/` に追記する拡張も検討余地がありますが、ネットワーク/`npx` 依存があるため初版はスキル単体で提供します。
