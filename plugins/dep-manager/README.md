# dep-manager

依存関係とツールチェーンの**バージョン管理**を支援するスキル集。[Renovate](https://docs.renovatebot.com/) による依存更新の自動化と、[mise](https://mise.jdx.dev/) によるツールチェーン管理を1つにまとめています。
(旧 `renovate` / `mise` を統合したプラグインです。)

## 構成

| スキル | 役割 |
|---|---|
| `/dep-manager:migrate-dependabot` | `.github/dependabot.yml` を検出し、等価な `renovate.json` を生成。Dependabot の無効化手順まで案内する |
| `/dep-manager:tune-renovate` | 既存 `renovate.json` に `minimumReleaseAge`(cooldown)・grouping・automerge・schedule ルールを対話的に追加する |
| `/dep-manager:enable-mise-manager` | `enabledManagers` に `mise` を追加し、`.mise.toml` のツールバージョンを Renovate の更新対象にする |
| `/dep-manager:mise-sync` | `.mise.toml` のツール定義と実環境(`mise ls` / `mise current`)の不整合を検出・修正し、`mise install` を確実に通す |
| `/dep-manager:mise-ci` | GitHub Actions の `jdx/mise-action` 設定を生成・更新(SHA pin + バージョンコメント、cache、後続の依存インストールとの連携) |

## 使い方

```bash
# Dependabot から Renovate へ移行
/dep-manager:migrate-dependabot

# 既存設定に cooldown + automerge を追加
/dep-manager:tune-renovate minor/patch は CI pass 後に自動マージ、cooldown 3日

# .mise.toml と実環境のズレを解消 → Renovate の更新対象に追加
/dep-manager:mise-sync
/dep-manager:enable-mise-manager

# CI に mise-action を組み込む
/dep-manager:mise-ci
```

## 設計思想

- **このリポジトリ自身の `renovate.json` / `.mise.toml` / `validate.yml` を模範例にする**。`config:recommended` ベース、`minimumReleaseAge`、`platformAutomerge`、minor/patch/digest の自動マージと頻出パッケージの週次まとめ、`jdx/mise-action` の SHA pin —— これらの実証済みパターンを再利用する。
- **major は手動のまま**にし、minor/patch/digest のみ自動マージを既定とする(破壊的変更の取りこぼし防止)。automerge を有効にするときは branch protection / required status checks の前提を必ず確認する。
- **固定バージョンを推奨**。`node = "24.17.0"` のように固定すると、Renovate が `.mise.toml` の更新 PR を作れる。`mise-sync` で整える → `enable-mise-manager` で更新対象にする、という流れで連携する。
- 破壊的操作はしない。`mise install` / `mise use` や `dependabot.yml` の削除は提案し、実行はユーザーの確認を得る。

## 関連

- `github` の `/github:review-dependabot` — Dependabot が作成済みの PR をレビューしたい場合(本プラグインは設定の投入・チューニングを担い、レイヤーが異なる)。
