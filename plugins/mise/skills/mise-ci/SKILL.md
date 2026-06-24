---
name: mise-ci
argument-hint: "[対象ワークフロー (optional)]"
description: GitHub Actions に jdx/mise-action を組み込む/設定を見直すスキル。SHA pin + バージョンコメント、cache、後続の依存インストール連携を整える
allowed-tools: Read Edit Bash(git:*)
---

# /mise:mise-ci — CI に mise-action を組み込む

GitHub Actions のワークフローに `jdx/mise-action` を組み込み、ローカルと CI で**同一のツールバージョン**を使う状態を作ります。
既存ワークフローがあれば設定を見直します。

`$ARGUMENTS` に対象ワークフロー名があればそれを、無ければ `.github/workflows/` を走査して候補を提示します。

## 実行手順

1. **対象の特定**: `.github/workflows/*.yml` を Read。`$ARGUMENTS` 指定があればそれを優先。mise を使うべきジョブ(ビルド/テスト/lint)を特定する。
2. **`.mise.toml` の確認**: 管理対象のツール(node / pnpm 等)を把握し、CI でも同じものが必要か確認する。
3. **mise-action ステップの生成**: `actions/checkout` の後に `jdx/mise-action` を置く。
   - **SHA で pin し、バージョンをコメントで残す**(このリポジトリの流儀):
     ```yaml
     - name: Setup mise
       uses: jdx/mise-action@e6a8b3978addb5a52f2b4cd9d91eafa7f0ab959d # v4.2.0
     ```
   - mise-action は既定でツールをキャッシュする。明示的に制御したい場合のみ `with: { cache: true }` 等を付ける。
4. **後続ステップとの連携**: ツールが使えるようになった後段で依存インストールを行う。例:
   ```yaml
   - name: Install dependencies
     run: pnpm install --frozen-lockfile
   ```
   `pnpm` 等は mise が提供するため、別途の setup-node 等は不要になることが多い(重複を削除する)。
5. **編集と差分提示**: Edit でワークフローを更新し、変更点を要約する。`actions/checkout` 等の他アクションも SHA pin されているか確認し、未 pin があれば指摘する(Renovate が更新できる形)。
6. **検証の案内**: YAML の妥当性確認を促し、可能なら PR 上で CI を回して確認するよう案内する。

## 模範例(このプラグイン集の validate.yml)

```yaml
steps:
  - name: Checkout repository
    uses: actions/checkout@df4cb1c069e1874edd31b4311f1884172cec0e10 # v6.0.3
  - name: Setup mise
    uses: jdx/mise-action@e6a8b3978addb5a52f2b4cd9d91eafa7f0ab959d # v4.2.0
  - name: Install dependencies
    run: pnpm install --frozen-lockfile
  - name: Validate
    run: pnpm run validate
```

## 注意

- アクションは**タグではなく SHA で pin**し、`# vX.Y.Z` コメントを残す(サプライチェーン対策 + Renovate での更新両立)。
- mise が node/pnpm を提供する構成では `actions/setup-node` 等と二重管理になりやすい。どちらかに統一する。

## 使用例

```bash
/mise:mise-ci
/mise:mise-ci ci.yml
```
