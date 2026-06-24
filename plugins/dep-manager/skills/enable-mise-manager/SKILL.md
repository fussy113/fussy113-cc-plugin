---
name: enable-mise-manager
argument-hint: ""
description: renovate.json の enabledManagers に mise を追加し、.mise.toml のツールバージョンを Renovate の自動更新対象にする
allowed-tools: Read Edit
---

# /dep-manager:enable-mise-manager — mise を Renovate の更新対象にする

`renovate.json` の `enabledManagers` に `"mise"` を追加し、`.mise.toml`(`[tools]` セクション)で固定している
ツールバージョン(node / pnpm / 各種ランタイム)を **Renovate が自動更新**できるようにします。

## 前提

- リポジトリに `.mise.toml`(または `mise.toml` / `.tool-versions`)が存在すること。無ければ `/dep-manager:mise-sync` を先に案内する。
- Renovate は mise マネージャをサポートしており、`[tools]` のバージョン指定を解釈して更新 PR を作る。

## 実行手順

1. **存在確認**: `.mise.toml` を Read し、`[tools]` のバージョン指定(例: `node = "24.17.0"`)を確認する。固定バージョンでないと Renovate は更新対象にできない旨を補足する。
2. **renovate.json の読み取り**: `enabledManagers` の現状を確認する。
   - 配列が存在し `"mise"` を含まない → 追記する。
   - `enabledManagers` 自体が無い → Renovate は既定で多数のマネージャを有効化するため、明示する場合は既存で使っているマネージャ(例: `github-actions`, `npm`)と合わせて `"mise"` を含む配列を作る。
3. **編集**: Edit で `enabledManagers` に `"mise"` を追加する。
   ```json
   "enabledManagers": ["github-actions", "mise", "npm"]
   ```
4. **検証の案内**: `jq . renovate.json` でパース確認。
5. **結果の表示**: 追加後の `enabledManagers` と、これにより `.mise.toml` の各ツールが更新 PR の対象になることを伝える。

## 注意

- `enabledManagers` を**明示すると、列挙したマネージャ以外は無効化**される。既に npm / github-actions 等を使っている場合は、それらを必ず配列に残すこと(取りこぼし防止)。
- `mise` で管理するツールに `minimumReleaseAge` を効かせたい場合は `/dep-manager:tune-renovate` で cooldown を設定する。

## 使用例

```bash
/dep-manager:enable-mise-manager
```

## 関連

- `.mise.toml` 自体の整備・CI 連携は同じ dep-manager の `/dep-manager:mise-sync` / `/dep-manager:mise-ci` を参照。
