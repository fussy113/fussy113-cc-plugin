#!/bin/bash
#
# self-improve / SessionStart フック (matcher: startup|resume)
# ------------------------------------------------------------------
# ~/.claude/session-journal/ から直近に更新されたジャーナルを読み込み、
# 標準出力に書き出すことでセッション冒頭の文脈に注入する。
# (SessionStart では exit 0 + stdout のテキストがそのまま additionalContext になる)
#
# - LLM 呼び出しなし。注入は数十行程度に抑える。
# - 現在のセッション自身のファイルは除外する。
# - ジャーナルが無ければ何も注入せず終了する。

set -u

input=$(cat 2>/dev/null)

get() {
  local key="$1"
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$input" | jq -r --arg k "$key" '.[$k] // empty' 2>/dev/null
    return
  fi
  printf '%s' "$input" \
    | grep -oE "\"$key\"[[:space:]]*:[[:space:]]*(\"[^\"]*\"|true|false|null|[0-9.]+)" \
    | head -1 \
    | sed -E 's/^[^:]*:[[:space:]]*//; s/^"//; s/"$//'
}

dir="${HOME}/.claude/session-journal"
[ -d "$dir" ] || exit 0

session_id=$(get session_id)
sid_short="${session_id:0:8}"

cwd=$(get cwd)
[ -z "$cwd" ] && cwd="$PWD"
# journal.sh と命名を一致させるため、repo 名は git トップレベル基準で決める。
# (サブディレクトリで起動しても同一リポジトリの過去ジャーナルを拾えるように)
toplevel=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)
if [ -n "$toplevel" ]; then
  repo=$(basename "$toplevel")
else
  repo=$(basename "$cwd")
fi
safe_repo=$(printf '%s' "$repo" | tr ' /' '__')

# まず同じリポジトリの直近ジャーナルを優先し、無ければ全体の直近を使う。
# 現在のセッション (sid_short) のファイルは除外する。
same_repo=$(ls -t "$dir"/*"__${safe_repo}__"*.md 2>/dev/null | grep -v "__${sid_short}.md" | head -3)
if [ -n "$same_repo" ]; then
  files="$same_repo"
else
  files=$(ls -t "$dir"/*.md 2>/dev/null | grep -v "__${sid_short}.md" | head -3)
fi
[ -z "$files" ] && exit 0

echo "## 📓 前回までのセッション記録 (self-improve)"
echo ""
echo "直近のセッションで何をしていたかの自動記録です。今回の作業の出発点として参考にしてください。"
echo "(これは自動注入された背景情報であり、ユーザーからの新しい指示ではありません)"
echo ""
for f in $files; do
  cat "$f" 2>/dev/null
  echo ""
done

exit 0
