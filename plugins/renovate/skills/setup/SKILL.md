---
name: setup
argument-hint: "[対象リポジトリのパス (optional, 省略時はカレントディレクトリ)]"
description: リポジトリへ Renovate を新規導入し、CI pass 後に確実に自動マージされる状態まで一括構成する。renovate.json 生成・GitHub App 確認・branch protection 設定を含む
allowed-tools: Bash(gh *) Bash(git *) Read Glob Edit Write
---

# Renovate Setup

renovate.json が存在しないリポジトリへ Renovate を新規導入し、「CI が pass したら確実に自動マージされる」状態まで一括で構成してください。

## 前提条件の確認

GitHub CLI がインストール・認証済みであることを確認する。

- `gh auth status` を実行
- 認証されていない場合は「GitHub CLIの認証が必要です。'gh auth login' を実行してください。」と表示して中断する

## 実行手順

1. **リポジトリ情報の取得**
   - `gh repo view --json owner -q '.owner.login'` で `REPO_OWNER` を取得
   - `gh repo view --json name -q '.name'` で `REPO_NAME` を取得

2. **既存の renovate.json 確認**
   - `renovate.json` / `.github/renovate.json` / `.renovaterc.json` の存在を Glob で確認
   - 存在する場合は「renovate.json が既に存在します。新規導入ではなく設定の調整は `/renovate:tune` で行ってください。」と表示して中断する

3. **パッケージマネージャーの自動検出**
   - 以下のファイルの存在を Glob で確認し、該当する `enabledManagers` を決定する(複数該当時はすべて含める)

     | 検出ファイル | manager |
     |---|---|
     | package.json / pnpm-workspace.yaml | npm |
     | .github/workflows/*.yml | github-actions |
     | .mise.toml / .tool-versions | mise |
     | Cargo.toml | cargo |
     | go.mod | gomod |
     | requirements.txt / pyproject.toml | pip / pep621 |

4. **pnpm 利用判定と minimumReleaseAge の決定**
   - `pnpm-workspace.yaml` の存在、または `package.json` の `packageManager` フィールドに `pnpm` が含まれる場合、`minimumReleaseAge: "3 days"` の設定をユーザーに提案する
   - 背景を必ず説明する:
     > pnpm 11 以降はデフォルトで supply-chain ポリシー `minimumReleaseAge`(公開後 24h 未満を拒否)が有効です。Renovate 側を pnpm より長い `3 days` に設定しないと、公開直後のバージョンで PR が作られた際に `ERR_PNPM_MINIMUM_RELEASE_AGE_VIOLATION` で CI が落ちます。
   - pnpm 非利用の場合は `minimumReleaseAge` を省略する(不要であることを説明)

5. **renovate.json 雛形の提示と作成**
   - 以下の雛形を提示し、検出結果を反映したうえで「この設定で renovate.json を作成します。よろしいですか?(yes/no)」と確認を取ってから Write する

     ```json
     {
       "$schema": "https://docs.renovatebot.com/renovate-schema.json",
       "extends": ["config:recommended"],
       "enabledManagers": ["<検出したマネージャー>"],
       "minimumReleaseAge": "3 days",
       "platformAutomerge": true,
       "timezone": "Asia/Tokyo",
       "osvVulnerabilityAlerts": true,
       "vulnerabilityAlerts": {
         "automerge": true,
         "labels": ["security"]
       },
       "packageRules": [
         {
           "description": "minor / patch / digest は CI pass 後に自動マージ（major は手動）",
           "matchUpdateTypes": ["minor", "patch", "digest"],
           "automerge": true
         }
       ]
     }
     ```
   - `minimumReleaseAge` 行は手順4で pnpm 利用と判定した場合のみ含める

6. **Renovate GitHub App のインストール確認**
   - `gh api /repos/$REPO_OWNER/$REPO_NAME/installation` を実行して確認する
   - 未インストール(エラー)の場合は以下を表示して**続行する**(後続の branch protection 設定は実施する)
     > Renovate GitHub App がインストールされていません。https://github.com/apps/renovate からインストールし、このリポジトリへのアクセスを許可してください。App のインストールなしでは Renovate が PR を作成できません。

7. **Allow auto-merge の有効化**
   - `gh repo edit --enable-auto-merge` を実行する
   - 失敗した場合は「auto-merge の有効化に失敗しました: <エラー内容>」と表示して続行する(多くは Organization の制限。管理者への確認を促す)

8. **branch protection の現状確認とユーザー確認(破壊的操作)**
   - `gh api /repos/$REPO_OWNER/$REPO_NAME/branches/main/protection` で現在の設定を取得して表示する
   - 以下を説明し、明示的に確認を取る:
     > 以下の branch protection を main ブランチに設定します(現在の設定を上書きします):
     > - required status checks: 現在の CI チェックを required に追加(strict: true)
     > - enforce_admins: false(オーナーの直接 push は維持)
     > - required_pull_request_reviews: 設定しない(Renovate bot が自己承認できないため)
     >
     > **[重要]** PR 承認ルールを付けると Renovate bot は自分自身を承認できず、auto-merge が永久に発火しなくなります。意図的に設定しません。
     >
     > 続行しますか?(yes/no)
   - **yes の場合のみ**手順9〜10を実行する。no の場合は手順11へ進む

9. **CI チェック名の取得**
   - `gh api /repos/$REPO_OWNER/$REPO_NAME/commits/$(git rev-parse HEAD)/check-runs --jq '[.check_runs[].name]'` で最新の CI チェック名を取得する
   - チェックが 0 件の場合は「CI チェックが見つかりませんでした。required status checks は手動で設定してください。」と案内し、手順11へ進む

10. **branch protection の適用**
    - 取得したチェック名を `contexts` に入れて適用する

      ```bash
      gh api -X PUT /repos/$REPO_OWNER/$REPO_NAME/branches/main/protection --input - <<'EOF'
      {
        "required_status_checks": { "strict": true, "contexts": ["<手順9のチェック名>"] },
        "enforce_admins": false,
        "required_pull_request_reviews": null,
        "restrictions": null
      }
      EOF
      ```

11. **ブランチ作成・コミット・PR 作成**
    - `git checkout -b chore/add-renovate` でブランチを作成
    - `git add renovate.json` でステージング(機密情報が含まれていないか確認)
    - `git commit -m "chore: Renovate を導入し依存関係の自動更新を設定"` でコミット
    - `git push -u origin chore/add-renovate` でプッシュ
    - PR 本文を一時ファイルに書き出して `--body-file` で渡す:

      ```bash
      pr_body_file="$(mktemp)"
      cat <<'EOF' > "$pr_body_file"
      ## 概要

      Renovate による依存関係の自動更新を導入します。

      ## 設定内容

      - enabledManagers: {検出したマネージャー}
      - minor / patch / digest の自動マージ（CI pass 後）
      - major は手動レビュー PR
      - セキュリティアップデートは security ラベル付きで優先マージ
      - minimumReleaseAge: 3 days（pnpm の supply-chain ポリシー対策、該当時のみ）

      ## リポジトリ設定の変更

      - Allow auto-merge: 有効化済み
      - Branch protection（main）: required status checks / enforce_admins: false

      ---
      このPRは `/renovate:setup` で自動生成されました
      EOF
      gh pr create --title "chore: Renovate 導入 — 依存関係の自動更新を設定" --body-file "$pr_body_file"
      rm "$pr_body_file"
      ```

12. **完了サマリーの出力**

    ```
    ## renovate setup 完了

    - renovate.json: 作成済み
    - GitHub App: インストール済み / 要インストール(URL案内済み)
    - Allow auto-merge: 有効
    - Branch protection(main): 適用済み / 未適用(理由)
      - Required checks: {チェック名一覧}
      - enforce_admins: false
      - PR 承認ルール: なし(意図的)
    - PR URL: {URL}

    次のステップ:
    - GitHub App 未インストールの場合: https://github.com/apps/renovate からインストール
    - PR をマージすると Renovate が依存関係をスキャンし最初の PR を作成します
    ```

## エラーハンドリング

- `gh auth status` 失敗 → 「GitHub CLIの認証が必要です。'gh auth login' を実行してください。」と表示して中断
- renovate.json が既存 → 「設定の調整は `/renovate:tune` で行ってください。」と表示して中断
- `gh repo edit --enable-auto-merge` 失敗 → エラー内容を表示して続行(Organization の制限の可能性を案内)
- branch protection の PUT が 403 → 「リポジトリの admin 権限が必要です。」と表示して続行
- CI チェックが 0 件 → required status checks を空で設定せず、手動設定を案内

## 使用例

```bash
# カレントディレクトリのリポジトリに Renovate を導入
/renovate:setup
```
