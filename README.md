# claude-code-marketplace

Claude Code plugin と Codex plugin を同じリポジトリで管理するための実験用 marketplace です。

## 目的

- Claude Code 向け plugin を維持しながら、Codex 向け plugin も同じ repo で配布する
- 共通化できる skill は 1 つの原本から Claude/Codex 向けに生成する
- MCP や hook など、skill 以外の plugin 資産もできるだけ共通管理する

## 現在の構成

- `plugins/*/.claude-plugin/plugin.json`: Claude Code 向け manifest
- `plugins/*/.codex-plugin/plugin.json`: Codex 向け manifest
- `plugins/github/shared-skills/*`: 共通 skill 原本
- `plugins/github/skills/*`: Claude Code 向け生成物
- `plugins/github/codex-skills/*`: Codex 向け生成物
- `scripts/sync-skills.mjs`: 共通原本から生成物を同期する CLI

## 編集ルール

- 手編集するのは `shared-skills/` 配下のみ
- `skills/` と `codex-skills/` は自動生成物として扱う
- 既存 skill の本文を修正したい場合は、対応する `body.md` を更新してから `sync-skills.mjs` を実行する

## 同期コマンド

```bash
node scripts/sync-skills.mjs
node scripts/sync-skills.mjs --check
node scripts/sync-skills.mjs --plugin github
node scripts/sync-skills.mjs --plugin github --skill quick-pr
```

## 対象 plugin

- `github`: 共通 skill 原本あり。Claude/Codex 両方へ生成
- `context7`: MCP 中心 plugin として Codex へ移植
- `tools-for-mac`: hook 中心 plugin として Codex へ移植
