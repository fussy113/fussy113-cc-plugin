---
name: migrate-dependabot
argument-hint: "[dependabot.yml のパス (optional, 省略時は .github/dependabot.yml)]"
description: dependabot.yml を読み取って等価な renovate.json に変換し、dependabot を無効化する PR を作成する。変換マッピングと注意点を提示してから実行する
allowed-tools: Bash(gh *) Bash(git *) Read Glob Edit Write
---

# Migrate from Dependabot

dependabot.yml を読み取って等価な renovate.json に変換し、dependabot を無効化する PR を作成してください。

## 前提条件の確認

GitHub CLI がインストール・認証済みであることを確認する。

- `gh auth status` を実行
- 認証されていない場合は「GitHub CLIの認証が必要です。'gh auth login' を実行してください。」と表示して中断する

## 実行手順

1. **dependabot.yml の読み取り**
   - `$ARGUMENTS` が指定された場合はそのパスを、省略時は `.github/dependabot.yml` を Read で取得する
   - 存在しない場合は「dependabot.yml が見つかりません。パスを引数で指定してください。例: `/renovate:migrate-dependabot .github/dependabot.yml`」と表示して中断する

2. **renovate.json の既存確認**
   - `renovate.json` / `.github/renovate.json` / `.renovaterc.json` を Glob で確認する
   - 存在する場合は「renovate.json が既に存在します。dependabot.yml の設定を既存にマージしますか? 新規作成して上書きしますか?(merge/overwrite/cancel)」と確認する。cancel の場合は中断する

3. **dependabot.yml の解析と変換マッピングの提示**
   - dependabot.yml を解析し、以下の変換マッピングを提示する

     | dependabot 設定 | renovate.json 相当 | 備考 |
     |---|---|---|
     | package-ecosystem: npm | enabledManagers: ["npm"] | |
     | package-ecosystem: github-actions | enabledManagers: ["github-actions"] | |
     | package-ecosystem: pip | enabledManagers: ["pip"] | |
     | directory: "/" | (デフォルト動作、設定不要) | |
     | schedule.interval: daily | (Renovate はデフォルト毎日) | |
     | schedule.interval: weekly | schedule: ["before 6am on monday"] | |
     | schedule.interval: monthly | schedule: ["before 6am on the first day of the month"] | |
     | ignore: [{name, versions}] | packageRules + matchPackageNames / enabled: false | |
     | labels: [...] | labels: [...] | vulnerabilityAlerts にも適用推奨 |
     | reviewers: [...] | reviewers: [...] | |
     | assignees: [...] | assignees: [...] | Renovate は reviewers を推奨 |
     | open-pull-requests-limit | prConcurrentLimit | |
     | target-branch | baseBranches: [...] | |

   - 変換できない設定があれば「手動対応が必要な項目」として列挙する

4. **変換結果の提示と確認**
   - 変換後の renovate.json を提示し、以下の注意事項を添える:
     > - Renovate は依存関係マネージャーを `enabledManagers` で統一管理します
     > - dependabot では ecosystem ごとに設定を分けますが、Renovate では `packageRules` でパッケージごとに細かく制御します
     > - 移行後は `/renovate:setup` で auto-merge 構成(branch protection)を行うことを推奨します
   - 「上記の内容で進めますか?(yes/no)」と確認を取り、yes の場合のみ続行する

5. **renovate.json の書き込み**
   - 手順2の選択に応じて Write(新規/上書き)または Edit(マージ)で renovate.json を作成する

6. **dependabot の無効化**
   - 以下の選択肢を提示する:
     1. 削除する(PR に削除コミットを含める)
     2. disable コメントを追記してリポジトリに残す
     3. そのままにする(手動で処理)
   - 2 を選択した場合は dependabot.yml の先頭に以下を追記する:
     ```
     # [DISABLED] Renovate に移行済み。このファイルは参照用に残しています。
     ```

7. **Renovate GitHub App のインストール確認**
   - `gh api /repos/{owner}/{repo}/installation` で確認する(owner/repo は `gh repo view` で取得)
   - 未インストールの場合は「Renovate GitHub App がインストールされていません。https://github.com/apps/renovate からインストールしてください。」と表示して続行する

8. **ブランチ作成・コミット・PR 作成**
   - `git checkout -b chore/migrate-to-renovate` でブランチを作成
   - renovate.json と(削除/変更した場合は)dependabot.yml をステージングしてコミット: `git commit -m "chore: dependabot から Renovate へ移行"`
   - `git push -u origin chore/migrate-to-renovate` でプッシュ
   - PR 本文を一時ファイルに書き出して `--body-file` で渡す:

     ```bash
     pr_body_file="$(mktemp)"
     cat <<'EOF' > "$pr_body_file"
     ## 概要

     依存関係の自動更新ツールを dependabot から Renovate に移行します。

     ## 変換内容

     - {変換マッピングの要約}

     ## 手動対応が必要な項目

     - {変換できなかった項目、なければ「なし」}

     ## 移行後の推奨手順

     1. PR をマージ
     2. Renovate GitHub App が未インストールの場合: https://github.com/apps/renovate からインストール
     3. auto-merge 構成が未設定の場合: `/renovate:setup` を実行して branch protection を構成

     ---
     このPRは `/renovate:migrate-dependabot` で自動生成されました
     EOF
     gh pr create --title "chore: dependabot から Renovate へ移行" --body-file "$pr_body_file"
     rm "$pr_body_file"
     ```

9. **完了サマリーの出力**

   ```
   ## migrate-dependabot 完了

   - renovate.json: 作成済み
   - dependabot.yml: 削除済み / disabled コメント追記済み / 変更なし
   - GitHub App: インストール済み / 要インストール(URL案内済み)
   - PR URL: {URL}

   次の推奨アクション:
   - PR をマージ後、`/renovate:setup` で auto-merge 構成(branch protection)を完了させてください
   ```

## エラーハンドリング

- dependabot.yml が存在しない → パス指定を案内して中断
- `gh auth status` 失敗 → 「GitHub CLIの認証が必要です。'gh auth login' を実行してください。」と表示して中断
- 変換できない dependabot 設定が存在 → 変換不可の項目を明示し、手動設定を案内してから続行
- renovate.json 既存かつ上書き選択 → 既存内容のバックアップ要否を確認する
- ブランチが既に存在 → ブランチ名のサフィックスに日付を追加して再試行

## 使用例

```bash
# デフォルトパスの dependabot.yml を移行
/renovate:migrate-dependabot

# パスを指定して移行
/renovate:migrate-dependabot .github/dependabot.yml
```
