# effort-router

タスクの規模に応じて **effort レベル・モデル・実行モードを使い分ける**ための判定スキル。
「小さいタスクに大きな計算を使わない／大きいタスクに小さな計算で挑まない」を徹底し、品質を保ちながらトークンを節約します。

## 使い方

```bash
# タスクを渡して見積もり
/effort-router DBをMySQLからPostgreSQLに移行する

# 直近の指示・差分から自動推定
/effort-router
```

タスクを **規模 / 不確実性 / 可逆性 / 反復性** の4軸で評価し、T0(雑務)〜T4(探索・監査)のティアに分類して、
推奨する `/effort` レベル・`/model`・`/fast`・プランモード・dynamic workflow を適用コマンド付きで提示します。

## 調整できるつまみ

| つまみ | コマンド | 用途 |
|---|---|---|
| effort | `/effort low\|medium\|high\|xhigh\|max` | 思考の深さ＝トークン消費 |
| ultracode | `/effort` メニュー | xhigh ＋ dynamic workflows |
| モデル | `/model haiku\|sonnet\|opus` | 軽量〜高性能 |
| fast mode | `/fast` | 同品質で高速・対話的反復向き(単価は上昇) |
| 局所熟考 | `ultrathink` をプロンプトに | その1ターンだけ深く推論 |

## ティアの目安

| ティア | 例 | effort | モデル |
|---|---|---|---|
| T0 雑務 | typo、単純質問 | low | haiku/sonnet |
| T1 小 | 小バグ修正、小機能 | medium | sonnet |
| T2 中 | リファクタ、機能実装、CI/renovate設定 | high(既定) | sonnet/opus |
| T3 大 | DB/PM移行、アーキ変更 | xhigh/max | opus |
| T4 探索/監査 | 広域監査、横断調査 | ultracode | opus |

詳細なルーブリックと判断基準は `skills/effort-router/SKILL.md` を参照してください。

## 関連

- 自己学習フィードバックループは `self-improve` プラグインを参照。
