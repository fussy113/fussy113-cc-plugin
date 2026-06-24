---
name: tune-renovate
argument-hint: "[追加したいルール (optional)]"
description: 既存の renovate.json に cooldown(minimumReleaseAge)・grouping・automerge・schedule ルールを対話的に追加する。Renovate の挙動を調整したいときに使う
allowed-tools: Read Edit
---

# /renovate:tune-renovate — Renovate 設定のチューニング

既存の `renovate.json` を読み取り、運用で効くルール(cooldown / grouping / automerge / schedule)を**安全に追記**します。

`$ARGUMENTS` に要望があればそれを優先し、無ければ現状を診断して改善案を提示します。

## 調整できる主なルール

| ルール | キー | 効果 |
|---|---|---|
| cooldown | `minimumReleaseAge` | 公開直後の不安定なリリースを避ける(例: `"3 days"`)。サプライチェーン対策としても有効 |
| 自動マージ | `packageRules[].automerge` + `platformAutomerge` | CI pass 後に PR を自動マージ。`matchUpdateTypes` で対象を絞る |
| グルーピング | `packageRules[].groupName` | 関連パッケージを1つの PR にまとめ、ノイズを減らす |
| スケジュール | `packageRules[].schedule` | 更新の多いパッケージを週次などにまとめる(例: `["before 6am on monday"]`) |
| 脆弱性早期反映 | `vulnerabilityAlerts` / `osvVulnerabilityAlerts` | security 更新は schedule をバイパスして即時 PR |
| 同時 PR 数 | `prConcurrentLimit` / `prHourlyLimit` | PR の洪水を防ぐ |

## 実行手順

1. **現状の読み取り**: `renovate.json`(無ければ `.renovaterc(.json)`)を Read。存在しなければ `/renovate:migrate-dependabot` を案内して終了。
2. **診断**: 現在の設定を評価し、欠けている/緩い点を指摘する(例: cooldown 無し、automerge が major まで含む、頻出パッケージの schedule 未設定)。
3. **追記内容の決定**: `$ARGUMENTS` の要望を反映。曖昧なら 1〜2 問だけ確認する(例: 「automerge の対象は minor/patch/digest だけで良いか?」)。
4. **安全な編集**: 既存の `packageRules` を壊さないよう**配列に追記**する。`major` を automerge 対象に含めないことを既定とする。Edit で更新。
5. **検証の案内**: `jq . renovate.json` でパース確認、可能なら `npx --yes renovate-config-validator` での検証を提案する。
6. **結果の表示**: 追加したルールと、その前提(branch protection / required status checks)を併記する。

## 模範例(このプラグイン集自身の renovate.json より)

```json
{
  "minimumReleaseAge": "3 days",
  "platformAutomerge": true,
  "vulnerabilityAlerts": { "automerge": true, "labels": ["security"] },
  "packageRules": [
    {
      "description": "minor / patch / digest は CI pass 後に自動マージ（major は手動PRのまま）",
      "matchUpdateTypes": ["minor", "patch", "digest"],
      "automerge": true
    },
    {
      "description": "更新頻度が高いパッケージは自動マージ対象を週次にまとめる（security は vulnerabilityAlerts がバイパス）",
      "matchPackageNames": ["@anthropic-ai/claude-code"],
      "matchUpdateTypes": ["minor", "patch", "digest"],
      "schedule": ["before 6am on monday"],
      "automerge": true
    }
  ]
}
```

## 注意

- **automerge と branch protection はセット**。required status checks が無いと、CI を待たずにマージされうる。
- cooldown(`minimumReleaseAge`)は便利だが、長すぎると security 更新まで遅れる。security は `vulnerabilityAlerts` で別経路にする。
- グルーピングしすぎると 1 PR の差分が大きくなり、原因切り分けが難しくなる。粒度に注意。

## 使用例

```bash
/renovate:tune-renovate cooldown 3日 と minor/patch の自動マージを追加
/renovate:tune-renovate eslint 関連を 1 PR にグルーピング
```
