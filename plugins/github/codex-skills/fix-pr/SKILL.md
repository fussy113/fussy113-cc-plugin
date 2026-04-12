---
name: 'fix-pr'
description: 'PRのCI失敗やレビューコメントを自動的に調査し、コード修正・コミット・コメント返信・スレッド解決を行う。GitHub CLIが必要'
---

<!--
このファイルは scripts/sync-skills.mjs により自動生成されています。
編集は `plugins/github/shared-skills/fix-pr` を更新してください。
-->
> 想定引数: `[PR番号 (optional)]`
> 推奨ツール: `gh`, `git`, `read`, `grep`, `glob`, `edit`

# PR 修正・対応

PRのCI失敗とレビューコメントを調査し、必要な修正を行い、コメントにreplyしてスレッドを解決します。

## 前提条件の確認

GitHub CLI がインストール・認証済みであることを確認してください：

```bash
gh auth status
```

認証されていない場合は処理を中断し、`gh auth login` を実行するよう案内してください。

## 実行手順

### 1. PR番号の特定

`$ARGUMENTS` が指定されている場合はその値をPR番号として使用します。

指定されていない場合は、現在のブランチに紐づくPRを自動検出します：

```bash
gh pr view --json number -q .number
```

PRが見つからない場合は処理を中断し、PR番号を引数として指定するよう案内してください。

### 2. リポジトリ情報の取得

後続の `gh api` 呼び出しで使用するため、リポジトリのオーナーとリポジトリ名を別々に取得します：

```bash
REPO_OWNER=$(gh repo view --json owner -q '.owner.login')
REPO_NAME=$(gh repo view --json name -q '.name')
```

### 3. PR情報の収集

以下のコマンドでPR全体の情報を取得します：

```bash
# PR基本情報
gh pr view <PR番号> --json title,body,baseRefName,headRefName,author,state

# 変更差分
gh pr diff <PR番号>

# CIチェックの状態
gh pr checks <PR番号>
```

### 4. CI失敗の調査と修正

`gh pr checks` の結果から失敗しているチェックを特定します。

各失敗チェックについて以下を実施してください：

1. **ログの取得**: チェック結果のURLからRun IDを特定し、失敗ログを取得します
   ```bash
   gh run view <run-id> --log-failed
   ```
   ログが大量の場合はエラー行・スタックトレースに集中して分析してください。

2. **原因の分類**:
   - **コードの問題**: テスト失敗、lintエラー、型エラーなど → 修正を実施
   - **インフラ/環境の問題**: タイムアウト、ネットワークエラー、OOMなど → コード修正は行わず記録のみ

3. **修正の実施**: コードの問題と判断した場合は Read/Grep/Glob でコードを調査し、Edit で修正を加えます。

複数の失敗がある場合は、まず全ての失敗を分析してから修正に着手してください。共通原因の場合は一括対応できます。

### 5. レビューコメントの調査と修正

GraphQL APIでレビュースレッドを取得します（thread IDと解決状態を含む）：

```bash
gh api graphql -f query='
  query($owner: String!, $repo: String!, $number: Int!) {
    repository(owner: $owner, name: $repo) {
      pullRequest(number: $number) {
        reviewThreads(first: 100) {
          nodes {
            id
            isResolved
            comments(first: 10) {
              nodes {
                id
                databaseId
                body
                author { login }
                path
                line
                originalLine
              }
            }
          }
        }
      }
    }
  }
' -f owner='<owner>' -f repo='<repo>' -F number=<PR番号>
```

未解決の各スレッドについて以下を実施してください：

1. **コメント内容の確認**: コメントで指摘されている内容を理解します
2. **コードの確認**: 指摘されているファイル・行のコードを Read/Grep で確認します
3. **対応の判断**:
   - **修正が必要**: バグ指摘、セキュリティ問題、明らかな改善点 → Edit で修正
   - **修正不要**: 質問への回答で済む場合、既存の設計・規約に従っている場合、スコープ外 → 修正なしで理由を記録

### 6. ローカル検証

修正を加えた場合は、コミット前にローカルで検証します。

プロジェクトのlinter・testコマンドをプロジェクト設定から検出してください：
- `package.json` の `scripts` フィールド（`lint`, `test`, `typecheck` など）
- `Makefile` のターゲット
- `pyproject.toml` / `setup.cfg`
- `Cargo.toml`
- その他プロジェクト固有のCIスクリプト

検出したコマンドを実行し、エラーが出た場合は追加修正を行ってください。

### 7. コミット

修正がある場合のみコミットします：

```bash
git add <修正したファイル>
git commit -m "<わかりやすいコミットメッセージ>"
```

コミットメッセージには以下を含めてください：
- 修正の概要（何を、なぜ修正したか）
- CI失敗への対応の場合はチェック名
- レビューコメントへの対応の場合は対応内容の要点

関連性のある修正はまとめて1コミットにし、独立した修正は別コミットにしてください。

### 8. コメント返信とスレッド解決

各レビュースレッドに返信し、解決します。

**返信の投稿**（レビューコメントに対するreply）:

```bash
gh api repos/<owner>/<repo>/pulls/<PR番号>/comments/<comment_databaseId>/replies \
  -f body="<返信内容>"
```

返信内容には以下を含めてください：
- **対応した場合**: 修正内容の説明、該当コミット
- **対応しなかった場合**: 対応しなかった理由（既存の設計方針、スコープ外、別の実装で同等の効果があるなど）

**スレッドの解決**:

```bash
gh api graphql -f query='
  mutation($threadId: ID!) {
    resolveReviewThread(input: {threadId: $threadId}) {
      thread { id isResolved }
    }
  }
' -f threadId='<thread_id>'
```

### 9. 結果サマリーの出力

全処理完了後、以下の形式でサマリーを出力してください：

```markdown
# fix-pr 実行結果サマリー

## CI失敗への対応

| チェック名 | 原因 | 対応 |
|---|---|---|
| [チェック名] | [原因の概要] | [修正内容 / インフラ起因のため対応なし] |

## レビューコメントへの対応

| ファイル | 行 | コメント概要 | 対応 |
|---|---|---|---|
| [path/to/file] | [行番号] | [コメント概要] | [修正内容 / 対応しなかった理由] |

## コミット

[コミットがある場合はハッシュとメッセージを列挙]
[修正がなかった場合は「コード修正なし」と記載]
```

## 注意事項

- 指摘内容を正確に理解してから修正に着手すること。不明な場合は安易に変更しない
- スタイルや好みの問題で既存コードの規約に従っている場合は、その旨を説明して変更しない
- 修正後は必ずローカル検証を通してからコミットすること
- PR差分のスコープ外の変更（無関係なリファクタリング等）は行わないこと
