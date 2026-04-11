---
name: quick-pr
argument-hint: "[branch_name (optional)]"
description: 変更内容を元にブランチ作成、コミット、プッシュ、Draft PR作成を一括実行
allowed-tools: Bash(git *) Bash(gh *)
---

# Quick PR

現在の変更内容をもとに、新しいブランチの作成からDraft PRの作成までを一括で実行してください。

## 実行手順

1. **現在の状態確認**
   - `git status` を実行して、変更されたファイルを確認
   - `git diff` を実行して、変更内容を取得
   - 変更がない場合は「変更内容が検出されませんでした」と表示して終了

2. **ブランチ名の決定**
   - 引数が指定されている場合: `$ARGUMENTS` をブランチ名として使用
   - 引数が省略されている場合: 変更内容を分析して自動生成
     - 変更の種類を判定（feature/fix/refactor/docs/chore）
     - 変更内容を簡潔に要約（kebab-case）
     - 日付を追加（YYYYMMDD形式）
     - 例: `feature/add-user-auth-20260129`

3. **新しいブランチの作成**
   - `git checkout -b {branch_name}` を実行
   - 既にブランチが存在する場合はエラーメッセージを表示

4. **コミットメッセージの生成**
   - 変更内容を分析して、Conventional Commits形式でメッセージを生成
   - 形式: `<type>: <subject>`
   - type: feat, fix, refactor, docs, test, chore など
   - subject: 変更の目的を簡潔に（50文字以内）

5. **ステージングとコミット**
   - `git add -A` で全ての変更をステージング
   - 機密情報（.env, credentials.jsonなど）が含まれていないか確認し、含まれていれば警告
   - `git commit -m "{生成されたコミットメッセージ}"` を実行

6. **リモートへのプッシュ**
   - `git push -u origin {branch_name}` を実行

7. **Draft PRの作成**
   - PRタイトル: コミットメッセージの見出しをベースに生成
   - PR本文: 以下の形式で生成
     ```
     ## 概要
     {変更内容の要約}

     ## 変更内容
     - {主な変更点を箇条書き}

     ---
     このPRは `/quick-pr` で自動生成されました
     ```
   - PR本文を一時ファイルに書き出し、`--body-file` で渡します：
     ```bash
     pr_body_file="$(mktemp)"
     cat <<'EOF' > "$pr_body_file"
     ## 概要
     {変更内容の要約}

     ## 変更内容
     - {主な変更点を箇条書き}

     ---
     このPRは `/quick-pr` で自動生成されました
     EOF
     gh pr create --draft --title "{タイトル}" --body-file "$pr_body_file"
     rm "$pr_body_file"
     ```

8. **結果の表示**
   以下の形式で出力:

   ```
   ## Quick PR 作成完了

   - ブランチ: {branch_name}
   - コミット: {commit_message}
   - PR URL: {pr_url}
   ```

## エラーハンドリング

- 変更がない場合 → 「変更内容が検出されませんでした。ファイルを編集してから実行してください。」
- ブランチ名が既に存在 → 「ブランチ '{branch_name}' は既に存在します。別の名前を指定してください。」
- gh CLIが未インストール → 「GitHub CLIが見つかりません。'gh'をインストールしてください。」
- gh CLIが未認証 → 「GitHub CLIの認証が必要です。'gh auth login'を実行してください。」

## 使用例

```bash
# ブランチ名を指定して実行
/quick-pr feature/add-login-button

# 自動生成されたブランチ名で実行
/quick-pr
```
