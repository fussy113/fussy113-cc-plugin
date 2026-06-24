#!/bin/bash
#
# guardrail / destructive-guard
# PreToolUse(Bash) フック。真に危険なコマンドのみ exit 2 でブロックする
# (exit 2 のとき stderr が Claude に差し戻され、ツール実行は中止される)。
#
# 設計方針: 「ブロックしすぎない」。誤検知を避けるため denylist は狭く保つ。
# 対象外・判定不能・jq 不在などは常に exit 0(作業を止めない)。
# 各ルールは不要なら該当 if ブロックをコメントアウトして無効化できる。
#
set -u

input="$(cat)"

# 実行コマンド文字列を取り出す(jq があれば厳密に、無ければ生入力で代替)
if command -v jq >/dev/null 2>&1; then
  cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)"
else
  cmd="$input"
fi
[ -z "${cmd:-}" ] && exit 0

# タブ→空白、連続空白を1つに正規化
norm="$(printf '%s' "$cmd" | tr '\t' ' ' | tr -s ' ')"

block() {
  echo "🛑 guardrail: 危険なコマンドを検出したためブロックしました。" >&2
  echo "   検出: $1" >&2
  echo "   代替: $2" >&2
  echo "   本当に必要な場合はユーザーが手動で実行してください。" >&2
  exit 2
}

# 1) rm -rf でルート/ホーム全体/全消しを狙うもの(サブディレクトリの削除は対象外)
if printf '%s' "$norm" | grep -Eqi 'rm +-[a-z]*(rf|fr)[a-z]* +(/|~|/\*|\$home)( |$)'; then
  block "rm によるルート/ホーム全体の再帰削除" "削除対象を具体的なパスで限定する"
fi

# 2) rm --no-preserve-root(ルート保護の無効化)
if printf '%s' "$norm" | grep -Eq 'rm .*--no-preserve-root'; then
  block "rm --no-preserve-root" "このフラグは使わない"
fi

# 3) git push --force / -f(--force-with-lease は許容)
if printf '%s' "$norm" | grep -Eq 'git +push' \
   && printf '%s' "$norm" | grep -Eq -- '(--force( |$)|--force=| -f( |$))' \
   && ! printf '%s' "$norm" | grep -Eq -- '--force-with-lease'; then
  block "git push --force(リモート履歴の上書き)" "git push --force-with-lease を使う"
fi

# 4) git --no-verify(commit/push フックの省略)
if printf '%s' "$norm" | grep -Eq 'git .*--no-verify'; then
  block "git --no-verify(pre-commit/pre-push フックの省略)" "フックを通す。理由があれば手動で実行する"
fi

# 5) git reset --hard(未コミット変更の喪失)
if printf '%s' "$norm" | grep -Eq 'git +reset .*--hard'; then
  block "git reset --hard(未コミット変更の喪失)" "git stash で退避してから操作する"
fi

# 6) SQL の DROP TABLE / DROP DATABASE
if printf '%s' "$norm" | grep -Eqi 'drop +(table|database) +'; then
  block "SQL の DROP TABLE/DATABASE" "対象を確認し、バックアップを取ってから実行する"
fi

exit 0
