# mise

[mise](https://mise.jdx.dev/) による**ツールチェーンのバージョン管理**を支援するプラグイン。
`.mise.toml` と実環境の整合確認・修正、CI(GitHub Actions)の `mise-action` 設定生成を、対話的なスキルで行います。

## 構成

| スキル | 役割 |
|---|---|
| `/mise:mise-sync` | `.mise.toml` のツール定義と実環境(`mise ls` / `mise current`)の不整合を検出・修正し、`mise install` を確実に通す |
| `/mise:mise-ci` | GitHub Actions の `jdx/mise-action` 設定を生成・更新(SHA pin + バージョンコメント、cache、後続の依存インストールとの連携) |

## 使い方

```bash
# .mise.toml と実環境のズレを解消
/mise:mise-sync

# CI に mise-action を組み込む / 設定を見直す
/mise:mise-ci
```

## 設計思想

- **このリポジトリ自身の `.mise.toml` と `validate.yml` を模範例にする**。`jdx/mise-action` を SHA で pin しつつバージョンコメントを残す、`mise install` 後に `pnpm install --frozen-lockfile` を続ける ——という実証済みの流れを再利用する。
- **固定バージョンを推奨**。`node = "24.17.0"` のように固定すると、Renovate が更新 PR を作れる(`renovate` プラグインの `/renovate:enable-mise-manager` と連携)。
- 破壊的操作はしない。`mise install` / `mise use` は提案し、実行はユーザーの確認を得る。

## 関連

- mise のツールバージョンを自動更新したい場合は `renovate` プラグインの `/renovate:enable-mise-manager` を使う。
- CI の依存インストール(`pnpm install --frozen-lockfile`)は `mise install` の後段に置くと安定する。
