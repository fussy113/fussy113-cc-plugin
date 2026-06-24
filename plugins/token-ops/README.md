# token-ops

Claude Code の**トークン効率を最大化**するスキル集。タスク着手前の effort 見積もり(`effort-router`)と、実際の消費コストの可視化(`ccusage`)を1つにまとめています。
(旧 `effort-router` / `ccusage` を統合したプラグインです。)

## 構成

| スキル | 役割 |
|---|---|
| `/token-ops:effort-router` | タスクを規模/不確実性/可逆性/反復性の4軸で T0〜T4 に分類し、`/effort`・`/model`・`/fast`・プランモード・dynamic workflow の推奨を適用コマンド付きで提示する |
| `/token-ops:ccusage` | 日次/週次/月次/セッション別のトークン消費とコストをターミナルに表示する(`npx ccusage` をローカル集計で実行) |

## 使い方

```bash
# 着手前にタスク規模で effort/モデルを見積もる
/token-ops:effort-router DBをMySQLからPostgreSQLに移行する
/token-ops:effort-router   # 直近の指示・差分から自動推定

# 実際に消費したトークン/コストを確認する
/token-ops:ccusage
/token-ops:ccusage month
```

## 設計思想 — 見積もりと実測で PDCA を回す

- **計測なくして効率化なし**。`effort-router` で「どの effort/モデルを使うか」を事前に判断し、`ccusage` で「実際にいくら使ったか」を可視化する。両者をセットで使うとトークン効率の PDCA が回る。
- **小さいタスクに大きな計算を使わない / 大きいタスクに小さな計算で挑まない**。既定の `high` で十分なことが多く、安易に `max` へ上げない。横断・設計・高リスク・広域監査にだけ `xhigh`/`max`/ultracode を使う。
- `ccusage` は `npx ccusage@latest` をローカルの使用ログに対して実行するだけで、外部送信はない(初回はダウンロードにネットワークが必要)。

## 関連

- `dev-discipline` の `/dev-discipline:spec-implement` は、実装規模の見積もりを本プラグインの `effort-router` に委譲する。
- `self-improve` — セッションの作業記録(git 差分の journal)。`ccusage` の「トークンコスト」と補完関係にある。
