# dev-discipline

開発の**規律を強制する**スキル集。仕様策定 → 実装 → テスト → デバッグの各局面で、「順序」と「ゴール」を崩さないためのガイドをまとめて提供します。
(旧 `spec-driven` / `tdd-cycle` / `systematic-debug` を統合したプラグインです。)

## 構成

| スキル | 役割 |
|---|---|
| `/dev-discipline:spec-clarify` | 仕様(テキスト/GitHub Issue/Notion/URL)を取り込み、8観点で壁打ちして曖昧さを解消し、`docs/spec/<日付>-<slug>.md` に実装方針を策定する |
| `/dev-discipline:spec-implement` | 策定済みの方針ドキュメントを入力に、`token-ops` の `effort-router` で規模を見積もってから実装を進める |
| `/dev-discipline:tdd-cycle` | RED(失敗テストを先に書く)→ GREEN(最小実装で通す)→ REFACTOR(整える)を強制する |
| `/dev-discipline:systematic-debug` | バグ・テスト失敗・CI 失敗の根本原因を「理解 → 仮説 → 検証 → 修正」の4フェーズで追跡する |

## ワークフロー

```
要件(テキスト/Issue/Notion/URL)
        │  /dev-discipline:spec-clarify
        ▼
  壁打ち・深掘り(受け入れ条件・スコープ外を合意)
        │
        ▼
  docs/spec/<日付>-<slug>.md  ← 実装方針ドキュメント
        │  /dev-discipline:spec-implement
        ▼
  effort 見積もり(token-ops の effort-router へ委譲)→ タスク分解順に実装 → 検証
        │
        ├─ テスト先行で進めたい  → /dev-discipline:tdd-cycle
        └─ バグの根本原因を追う  → /dev-discipline:systematic-debug
```

## 使い方

```bash
# 仕様を取り込んで方針ドキュメントを作る
/dev-discipline:spec-clarify https://github.com/owner/repo/issues/42
# 方針ドキュメントから実装する
/dev-discipline:spec-implement docs/spec/20260624-user-auth.md
# テスト駆動で機能を追加する
/dev-discipline:tdd-cycle メールアドレスの形式チェック関数を追加
# 落ちた CI の根本原因を追う
/dev-discipline:systematic-debug pnpm install が CI でだけ失敗する
```

## 設計思想 — 3つの鉄則

- **合意なき実装をしない**(spec-clarify):受け入れ条件とスコープ外をユーザーと合意してから方針を確定する。
- **テストを書く前に実装を書かない**(tdd-cycle):期待する振る舞いを先に失敗するテストとして表現する。
- **理解していない問題を修正しない**(systematic-debug):原因を一文で説明できてから最小の修正を当てる。
- 規模に応じた effort/モデルの調整は二重管理せず、`token-ops` の `effort-router` スキルに委譲する。

## 関連

- `token-ops` — タスク規模に応じた effort/モデルの見積もり(`effort-router`)とトークン消費の可視化(`ccusage`)。
- `dep-manager` — 依存関係・ツールチェーンのバージョン管理。
