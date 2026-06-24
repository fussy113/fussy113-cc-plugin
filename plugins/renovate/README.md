# renovate

[Renovate](https://docs.renovatebot.com/) による**依存関係更新の自動化**を支援するプラグイン。
Dependabot からの移行・設定のチューニング・mise マネージャの有効化を、対話的なスキルで実行します。

## 構成

| スキル | 役割 |
|---|---|
| `/renovate:migrate-dependabot` | `.github/dependabot.yml` を検出し、等価な `renovate.json` を生成。Dependabot の無効化手順まで案内する |
| `/renovate:tune-renovate` | 既存 `renovate.json` に `minimumReleaseAge`(cooldown)・grouping・automerge・schedule ルールを対話的に追加する |
| `/renovate:enable-mise-manager` | `enabledManagers` に `mise` を追加し、`.mise.toml` のツールバージョンを Renovate の更新対象にする |

## 使い方

```bash
# Dependabot から Renovate へ移行
/renovate:migrate-dependabot

# 既存設定に cooldown + automerge を追加
/renovate:tune-renovate minor/patch は CI pass 後に自動マージ、cooldown 3日

# mise を更新対象に追加
/renovate:enable-mise-manager
```

## 設計思想

- **このリポジトリ自身の `renovate.json` を模範例にする**。`config:recommended` ベース、`minimumReleaseAge`、`platformAutomerge`、`packageRules` による minor/patch/digest 自動マージと頻出パッケージの週次まとめ、`vulnerabilityAlerts` のセキュリティ早期反映 ——これらの実証済みパターンを再利用する。
- **生成して終わりにしない**。automerge を有効にするときは branch protection / required status checks の前提を必ず確認する。
- **major は手動のまま**にし、minor/patch/digest のみ自動マージを既定とする(破壊的変更の取りこぼし防止)。

## 関連

- ツールチェーン本体のバージョン管理は `mise` プラグインを参照(`enable-mise-manager` で連携)。
- Dependabot が作成済みの PR をレビューしたい場合は `github` プラグインの `/review-dependabot` を使う(本プラグインは設定の投入・チューニングを担い、レイヤーが異なる)。
