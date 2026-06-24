# spec-driven

仕様要件を**取り込み → 壁打ちで方針策定 → 実装**へとつなぐプラグイン。
テキスト・GitHub Issue・Notion・URL で渡された要件を対話で深掘りし、実装方針を `docs/spec/` に残してから、`effort-router` と連携して実装まで導きます。

## 構成

| スキル | 役割 |
|---|---|
| `/spec-driven:spec-clarify` | 仕様(テキスト/GitHub Issue/Notion/URL)を取り込み、8観点で壁打ちして曖昧さを解消し、`docs/spec/<日付>-<slug>.md` に実装方針を策定する |
| `/spec-driven:spec-implement` | 策定済みの方針ドキュメントを入力に、`effort-router` で規模を見積もってから実装を進める |

## ワークフロー

```
要件(テキスト/Issue/Notion/URL)
        │  /spec-driven:spec-clarify
        ▼
  壁打ち・深掘り(受け入れ条件・スコープ外を合意)
        │
        ▼
  docs/spec/<日付>-<slug>.md  ← 実装方針ドキュメント
        │  /spec-driven:spec-implement
        ▼
  effort 見積もり(effort-router 委譲)→ タスク分解順に実装 → 検証 → 完了報告
```

`spec-clarify` は方針策定までで止まり、コードは変更しません。ユーザーが方針を確認・合意してから `spec-implement` で実装に進む、という2段構えです。

## 使い方

```bash
# 1. 仕様を取り込んで壁打ち → 方針ドキュメントを作る
/spec-driven:spec-clarify https://github.com/owner/repo/issues/42
/spec-driven:spec-clarify https://www.notion.so/xxxxxxxx
/spec-driven:spec-clarify メール+パスワードのログイン機能を追加したい

# 2. 策定した方針ドキュメントをもとに実装する
/spec-driven:spec-implement docs/spec/20260624-user-auth.md
/spec-driven:spec-implement   # 省略時は docs/spec/ の最新を使う
```

## 設計思想

- **合意なき実装をしない**。受け入れ条件とスコープ外をユーザーと言語化・合意してから方針を確定する(`spec-clarify` の鉄則)。
- **取り込み元を選ばない**。GitHub Issue は `gh`、一般 URL は `WebFetch`、Notion は MCP→WebFetch→貼り付けの3段フォールバックで吸収する。
- **規模に応じて effort を調整する**。判定ロジックは二重管理せず、実績ある `effort-router` に委譲する。

## 関連

- `effort-router` — タスク規模 → effort/モデルの見積もり(`spec-implement` が委譲)。
- `tdd-cycle` — 実装を TDD で進めたい場合に併用。
- `systematic-debug` — 実装中にバグの根本原因を追跡したい場合に併用。
