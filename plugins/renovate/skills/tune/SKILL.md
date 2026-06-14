---
name: tune
argument-hint: "[チューニング内容の概要 (optional)]"
description: 稼働中の renovate.json をインタラクティブにチューニングする。grouping・schedule・minimumReleaseAge・automerge 範囲などを対話しながら調整し PR を作成する
allowed-tools: Bash(gh *) Bash(git *) Read Edit Write
---

# Renovate Tune

稼働中の renovate.json を対話的にチューニングしてください。リポジトリ設定(branch protection 等)には触れず、renovate.json のファイル内容のみを扱います。

## 前提条件の確認

GitHub CLI がインストール・認証済みであることを確認する。

- `gh auth status` を実行
- 認証されていない場合は「GitHub CLIの認証が必要です。'gh auth login' を実行してください。」と表示して中断する

## 実行手順

1. **現在の renovate.json の読み取り**
   - `renovate.json` / `.github/renovate.json` / `.renovaterc.json` を Read で取得する
   - 存在しない場合は「renovate.json が見つかりません。新規導入には `/renovate:setup` を使用してください。」と表示して中断する

2. **現在の設定の可視化**
   - 読み取った設定をもとに、現状を日本語のテーブルでサマリー表示する

     | 設定項目 | 現在値 | 説明 |
     |---|---|---|
     | enabledManagers | {値} | 対象マネージャー |
     | minimumReleaseAge | {値 / 未設定} | 公開後の待機時間 |
     | automerge (packageRules) | {対象 update types} | 自動マージ範囲 |
     | schedule | {値 / 未設定} | 更新スケジュール |
     | timezone | {値} | タイムゾーン |
     | grouping | {あり / なし} | パッケージグループ |

3. **チューニング対象の決定**
   - `$ARGUMENTS` が指定されている場合はその内容をチューニング対象として解釈する
   - 指定がない場合は、以下の選択肢を提示して対話する(複数選択可):
     1. **automerge 範囲** — 自動マージ対象の update type を変更(例: major を追加、digest のみ除外)
     2. **schedule** — 特定パッケージの更新スケジュールを制限(例: 週1回)
     3. **minimumReleaseAge** — 公開後の待機時間(pnpm の supply-chain 対策: 推奨 3 days)
     4. **grouping** — 関連パッケージをまとめて1PRに
     5. **enabledManagers** — 対象マネージャーの追加/削除
     6. **その他**(自由記述)

4. **項目別チューニングガイド**
   - 選択された項目について、以下の情報を提示しつつ確認を取りながら値を決定する

   **automerge 範囲**
   - 推奨: minor/patch/digest は `automerge: true`、major は手動レビュー(automerge しない)
   - 注意: `automerge: true` だけでは「CI を待ってのマージ」は保証されない。`platformAutomerge: true` と branch protection の required status checks が併せて必要(構成は `/renovate:setup` の責務)

   **schedule**
   - 更新頻度が高いパッケージを週次にまとめる例:
     ```json
     {
       "matchPackageNames": ["<パッケージ名>"],
       "matchUpdateTypes": ["minor", "patch", "digest"],
       "schedule": ["before 6am on monday"]
     }
     ```
   - 注意: `vulnerabilityAlerts` は schedule をバイパスするため、セキュリティアップデートは schedule を設定しても即時反映される

   **minimumReleaseAge**
   - pnpm 利用プロジェクトでは `"3 days"` を推奨(pnpm の supply-chain ポリシー 24h より長く設定し `ERR_PNPM_MINIMUM_RELEASE_AGE_VIOLATION` を回避)
   - 非 pnpm の場合は省略可

   **grouping**
   - 関連パッケージをまとめる例(`matchPackageNames` の glob を使う。`matchPackagePatterns` は非推奨のため使わない):
     ```json
     {
       "matchPackageNames": ["@scope/**"],
       "groupName": "scope packages"
     }
     ```

   **enabledManagers**
   - 利用可能なマネージャー例: npm / github-actions / mise / cargo / gomod / pip / pep621

5. **変更内容の確認**
   - 決定した変更内容を差分で提示し、「以下の変更を renovate.json に適用します。適用しますか?(yes/no)」と確認を取る
   - yes の場合のみ Edit で適用する

6. **ブランチ作成・コミット・PR 作成**
   - `git checkout -b chore/tune-renovate-{YYYYMMDD}` でブランチを作成
   - `git add` でステージング、`git commit -m "chore: renovate.json をチューニング — {変更概要}"` でコミット
   - `git push -u origin chore/tune-renovate-{YYYYMMDD}` でプッシュ
   - PR 本文を一時ファイルに書き出して `--body-file` で渡す:

     ```bash
     pr_body_file="$(mktemp)"
     cat <<'EOF' > "$pr_body_file"
     ## 変更内容

     - {変更項目と理由を箇条書き}

     ---
     このPRは `/renovate:tune` で自動生成されました
     EOF
     gh pr create --title "chore: renovate.json チューニング — {変更概要}" --body-file "$pr_body_file"
     rm "$pr_body_file"
     ```

7. **完了サマリーの出力**

   ```
   ## renovate tune 完了

   - 変更項目: {項目名}
   - 変更内容: {概要}
   - PR URL: {URL}
   ```

## エラーハンドリング

- renovate.json が存在しない → 「新規導入には `/renovate:setup` を使用してください。」と表示して中断
- `gh auth status` 失敗 → 「GitHub CLIの認証が必要です。'gh auth login' を実行してください。」と表示して中断
- 変更内容が現状と同一 → 「変更内容がありません。設定は既に目標の状態です。」と表示して終了
- ブランチが既に存在 → ブランチ名のサフィックスに時刻を追加して再試行

## 使用例

```bash
# 対話的にチューニング
/renovate:tune

# 内容を指定して実行
/renovate:tune @anthropic-ai/claude-code を週次スケジュールにまとめたい
```
