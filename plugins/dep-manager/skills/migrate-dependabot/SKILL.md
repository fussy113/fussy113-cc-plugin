---
name: migrate-dependabot
argument-hint: "[追加要望 (optional)]"
description: .github/dependabot.yml を検出して等価な renovate.json を生成し、Dependabot の無効化までを案内する。Dependabot から Renovate へ移行したいときに使う
allowed-tools: Read Edit Bash(gh:*) Bash(git:*)
---

# /dep-manager:migrate-dependabot — Dependabot から Renovate へ移行

既存の `.github/dependabot.yml` を読み取り、**等価かそれ以上の `renovate.json`** を生成します。
生成後は Dependabot を無効化する手順まで案内し、二重に PR が作られる状態を防ぎます。

`$ARGUMENTS` に追加要望(例: 「cooldown 3日」「minor は自動マージ」)があれば反映します。

## 実行手順

1. **現状の把握**
   - `.github/dependabot.yml` を Read する。無ければ「Dependabot 設定が見つかりません」と伝え、ゼロから作るか確認する。
   - 既に `renovate.json` / `.renovaterc` が存在する場合は上書きせず、差分の追記提案に切り替える。
   - リポジトリのエコシステムを確認(`package.json`/`Gemfile`/`go.mod`/`.github/workflows/`/`.mise.toml` 等)し、必要な `enabledManagers` を判断する。

2. **dependabot.yml → renovate.json の対応付け**
   - `package-ecosystem` → `enabledManagers`(例: `npm` → `npm`、`github-actions` → `github-actions`、`bundler` → `bundler`)。
   - `schedule.interval` → Renovate は既定で必要時に PR を作るため、原則そのまま。頻度を抑えたい場合のみ `schedule` を設定。
   - `open-pull-requests-limit` → `prConcurrentLimit`。
   - `groups` → `packageRules` の `groupName`。
   - `ignore` → `packageRules` の `matchPackageNames` + `enabled: false`、または `matchUpdateTypes` の除外。
   - `labels` → `labels`。

3. **renovate.json の生成**
   - `config:recommended` を `extends` のベースにする。
   - 既定として安全な構成を入れる:
     ```json
     {
       "$schema": "https://docs.renovatebot.com/renovate-schema.json",
       "extends": ["config:recommended"],
       "enabledManagers": ["github-actions", "npm"],
       "minimumReleaseAge": "3 days",
       "platformAutomerge": true,
       "timezone": "Asia/Tokyo",
       "osvVulnerabilityAlerts": true,
       "vulnerabilityAlerts": { "automerge": true, "labels": ["security"] },
       "packageRules": [
         {
           "description": "minor / patch / digest は CI pass 後に自動マージ（major は手動PRのまま）",
           "matchUpdateTypes": ["minor", "patch", "digest"],
           "automerge": true
         }
       ]
     }
     ```
   - `$ARGUMENTS` の要望を反映する。
   - Edit で `renovate.json` を書き出す。

4. **Dependabot の無効化**
   - `.github/dependabot.yml` を削除するか、`updates:` を空にする方針を提示する(両者が同時に PR を作る状態を避ける)。実際の削除はユーザーの確認を得てから行う。
   - Dependabot の security updates だけ残したい場合は、Renovate 側の `vulnerabilityAlerts` で代替できる旨を説明する。

5. **前提条件の確認**
   - automerge を有効にする場合、`platformAutomerge` が機能するには branch protection で required status checks が設定されている必要があることを伝える。
   - Renovate App / Mend のインストール状況を確認するよう促す(未導入なら GitHub Marketplace から導入が必要)。

6. **結果の表示**
   ```markdown
   ## Renovate 移行完了

   - 生成: renovate.json（enabledManagers: [...]）
   - Dependabot: [削除提案 / 残置]
   - automerge: [対象 updateTypes]
   - 次の確認: branch protection の required status checks / Renovate App の導入状況
   ```

## エラーハンドリング

- `dependabot.yml` が無い → 「Dependabot 設定が見つかりません。ゼロから `renovate.json` を作成しますか?」と確認。
- `renovate.json` が既存 → 上書きせず、`/dep-manager:tune-renovate` での追記を案内。
- JSON 整形に自信が無いとき → 生成後に `jq . renovate.json` でパースエラーが無いことを確認する。

## 使用例

```bash
/dep-manager:migrate-dependabot
/dep-manager:migrate-dependabot minor/patch は自動マージ、cooldown 3日、timezone Asia/Tokyo
```
