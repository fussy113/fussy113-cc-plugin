---
name: spec-implement
description: spec-clarifyで策定した方針ドキュメントを入力に、effort-routerで規模を見積もってから実装を進める。引数で方針MDのパスを渡す(省略時は docs/spec/ の最新を探す)
argument-hint: "[方針ドキュメントのパス (optional)]"
allowed-tools: Read Edit Write Glob Grep Bash(git status:*) Bash(git diff:*) Bash(git log:*) Bash(ls:*) Bash(pnpm:*) Bash(npm:*) Bash(npx:*)
---

# /dev-discipline:spec-implement — 方針ドキュメントから実装へ

`/dev-discipline:spec-clarify` で策定した実装方針ドキュメントを読み込み、**タスク規模に応じて effort を調整しながら**実装を進めます。
方針に書かれた受け入れ条件を満たすことをゴールとし、スコープ外には踏み込みません。

`$ARGUMENTS` に方針ドキュメントのパスがあればそれを使います。無ければ `docs/spec/` の最新ファイルを探します。

## 前提

- `/dev-discipline:spec-clarify` で方針ドキュメントが策定済みであること。
- 方針ドキュメントの**受け入れ条件・スコープ外がユーザーと合意済み**であること。
- effort 調整は `token-ops` プラグインの `effort-router` スキルに委譲する(未導入なら手順2のフォールバックに従う)。

## 実行手順

### 1. 方針ドキュメントの解決

- `$ARGUMENTS` にパスがあればそれを `Read` する。
- 無ければ `docs/spec/` の最新ファイルを探す:
  ```bash
  ls -t docs/spec/*.md 2>/dev/null   # 更新時刻の新しい順。先頭が最新
  ```
  一覧の先頭(最新)のファイルをユーザーに提示し、「これでよいか」を確認してから読む。
- どこにも見つからなければ、`/dev-discipline:spec-clarify` で先に方針を策定するよう案内して中断する。

読み込んだら「機能要件・受け入れ条件・スコープ外・タスク分解」を要約してユーザーに提示する。

### 2. 規模見積もりと effort 調整(effort-router へ委譲)

方針の「タスク分解」セクションから作業全体の規模を1〜2文に要約し、ユーザーに次を促す:

> 実装に最適な effort を見積もるため `/token-ops:effort-router <タスク概要>` を実行してください。

- effort-router の判定(T0〜T4)に従って effort/モデルを調整する。`/effort` `/model` `/fast` のセッション設定の適用はユーザーに促す。
- 判定が **T3/T4(大・探索)ならプランモードでの開始**を案内する。AI 側で制御できる範囲(プランモードに入る、調査をサブエージェントに外出しする等)は effort-router の定義どおり自律的に適用してよい。
- **`token-ops`(effort-router スキル)が未導入の場合**は、規模(触るファイル数)・不確実性・リスクを自分で一言ずつ見積もり、過不足ない進め方を選ぶ。

### 3. 実装前の確認

- 受け入れ条件を再掲し、これらを満たすことをゴールに据える。
- スコープ外を再掲し、そこには踏み込まないことを確認する。
- 方針の「ファイル/モジュール構成(案)」と実際のコードを `Glob`/`Grep`/`Read` で突き合わせ、ズレがあればユーザーに確認する。

### 4. タスクの実装

- 方針の「タスク分解」の順に、1タスクずつ実装する。
- 各タスク完了後、プロジェクトのテスト/リンタを検出して実行する(`package.json` の `scripts`、`Makefile`、`pyproject.toml` 等)。失敗したら次に進まず修正する。
- 1度に複数の無関係な変更を混ぜない。原因追跡が必要なバグに当たったら `/dev-discipline:systematic-debug` を、テストを先に書きたい場合は `/dev-discipline:tdd-cycle` を併用する。
- **`git add` / `commit` / `push` はこのスキルでは行わない(コミットが必要ならユーザーに委ねる)。**

### 5. 完了報告

全タスク完了後、下記フォーマットで実装内容と受け入れ条件の達成状況を報告する。

## 出力フォーマット

```markdown
# spec-implement 実行結果

**方針ドキュメント**: [パス]

## 実装したタスク
| # | タスク | 状態 | 主な変更ファイル |
|---|---|---|---|
| 1 | [タスク] | 完了/未完 | [path] |

## 受け入れ条件の達成状況
- [x] [条件1]
- [ ] [条件2] — [未達の理由]

## 検証
- [実行したテスト/リンタとその結果]

## 残課題・申し送り
- [あれば。なければ「なし」]
```

## エラーハンドリング

- **方針ドキュメントが見つからない**: `/dev-discipline:spec-clarify` の実行を案内して中断する。
- **受け入れ条件が未定義**: 実装に進まず `/dev-discipline:spec-clarify` に戻して条件を合意する。
- **スコープ外の要求が発生**: その場で実装せず、ユーザーに方針を更新するか別タスクにするかを確認する。

## 注意事項

- スコープ外の実装・無関係なリファクタリングはしない。
- 各タスク後の検証(テスト/リンタ)を飛ばさない。結果は成否にかかわらず報告する。
- コミット・プッシュはこのスキルでは行わない(必要ならユーザーが手動で行う)。

## 使用例

```bash
/dev-discipline:spec-implement docs/spec/20260624-user-auth.md
/dev-discipline:spec-implement
```

## 関連

- `/dev-discipline:spec-clarify` — 方針ドキュメントの策定(このスキルの入力を作る)。
- `/token-ops:effort-router` — タスク規模に応じた effort/モデルの見積もり。
- `/dev-discipline:tdd-cycle` — 実装を TDD(RED→GREEN→REFACTOR)で進めたい場合。
- `/dev-discipline:systematic-debug` — 実装中にバグの根本原因を追跡したい場合。
