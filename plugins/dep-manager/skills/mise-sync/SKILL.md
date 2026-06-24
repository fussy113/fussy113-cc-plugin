---
name: mise-sync
argument-hint: ""
description: .mise.toml のツール定義と実環境(mise ls / mise current)の不整合を検出・修正し、mise install を確実に通す。ツールバージョンのズレや mise install 失敗を解消したいときに使う
allowed-tools: Read Edit Bash(mise:*)
---

# /dep-manager:mise-sync — .mise.toml と実環境の整合をとる

`.mise.toml` で宣言したツールバージョンと、実際にインストールされている環境の**不整合を検出**し、
`mise install` が確実に通る状態へ揃えます。

## 実行手順

1. **宣言の確認**: `.mise.toml`(無ければ `mise.toml` / `.tool-versions`)を Read し、`[tools]` のバージョン指定を把握する。無ければ「mise 設定が見つかりません」と伝え、最小構成の作成を提案する。
2. **実環境の確認**: `mise ls` と `mise current` を実行し、宣言と実体の差分(未インストール、別バージョンがアクティブ、`.mise.toml` に無いツール)を洗い出す。
3. **差分の提示**: 「宣言 vs 実環境」を表で示し、何が原因で `mise install` や CI が失敗しうるかを説明する。
4. **解消方針の提案**(実行は確認を得てから):
   - 未インストール → `mise install` を提案。
   - 宣言と実体のバージョン違い → `.mise.toml` を正とするか実体を正とするか確認し、`mise use <tool>@<version>` か `.mise.toml` の Edit で揃える。
   - lockfile(`mise.lock`)がある場合は整合を確認する。無く、再現性を高めたい場合は `mise.lock` の導入を任意で提案する。
5. **検証**: 揃えた後に `mise install` と `mise current` を実行し、宣言どおりのバージョンがアクティブであることを確認する。
6. **結果の表示**:
   ```markdown
   ## mise-sync 完了

   - 宣言: node=24.17.0, pnpm=11.8.0
   - 実環境: 一致 / 修正済み
   - 操作: [mise install / mise use ... / .mise.toml 編集]
   ```

## 注意

- `mise install` はネットワークアクセスを伴う。失敗時はミラー/プロキシ設定やバージョン表記(`24.17.0` のような完全指定か)を確認する。
- CI と手元で挙動を揃えたい場合、固定バージョン(`node = "24.17.0"`)を推奨する。範囲指定はドリフトの原因になる。
- `[env]` の `_.file = ".env"` のような設定がある場合、`.env` の有無で挙動が変わる点に注意する。

## 使用例

```bash
/dep-manager:mise-sync
```
