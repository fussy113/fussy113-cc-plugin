#!/bin/bash
#
# self-improve / Stop フック
# ------------------------------------------------------------------
# セッションが応答を終えるたびに、作業中リポジトリの git スナップショット
# (ブランチ・直近コミット・未コミット変更) を 1セッション=1ファイルで
# ~/.claude/session-journal/ に上書き保存する。
#
# - LLM 呼び出しは一切しないため、このフックによるトークンコストはゼロ。
# - 停止は決してブロックしない (常に exit 0)。
# - 非 git ディレクトリでは何も書かずに終了する。
# - 1セッションにつき1ファイルを上書きするので、ターンが進むたびに最新状態へ更新される。
#
# 標準入力には Stop フックの JSON (session_id, cwd, stop_hook_active など) が渡される。

set -u

input=$(cat)

# JSON フィールド取得: jq があれば使い、無ければ簡易フォールバック
get() {
  local key="$1"
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$input" | jq -r --arg k "$key" '.[$k] // empty' 2>/dev/null
  else
    printf '%s' "$input" \
      | grep -o "\"$key\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" \
      | head -1 \
      | sed 's/.*:[[:space:]]*"\(.*\)"/\1/'
  fi
}

# 継続ループ中 (Stop フックが block した結果の再実行) は二重記録しない
stop_active=$(get stop_hook_active)
[ "$stop_active" = "true" ] && exit 0

cwd=$(get cwd)
[ -z "$cwd" ] && cwd="$PWD"

cd "$cwd" 2>/dev/null || exit 0

# git リポジトリでなければ記録対象外
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

session_id=$(get session_id)
sid_short="${session_id:0:8}"
[ -z "$sid_short" ] && sid_short="nosid"

dir="${HOME}/.claude/session-journal"
mkdir -p "$dir" 2>/dev/null || exit 0

# 14日より古いジャーナルは掃除してファイル数を抑える
find "$dir" -maxdepth 1 -name '*.md' -type f -mtime +14 -delete 2>/dev/null

date_str=$(date +%Y-%m-%d)
time_str=$(date +%H:%M)
repo=$(basename "$cwd")
branch=$(git branch --show-current 2>/dev/null)
commits=$(git log --oneline -5 2>/dev/null)
changed=$(git status --short 2>/dev/null | head -20)

# ファイル名にスペース等が入らないよう repo を簡易サニタイズ
safe_repo=$(printf '%s' "$repo" | tr ' /' '__')
file="${dir}/${date_str}__${safe_repo}__${sid_short}.md"

{
  echo "## ${date_str} ${time_str} — ${repo}${branch:+ (${branch})}"
  echo ""
  if [ -n "$commits" ]; then
    echo "**直近コミット:**"
    echo '```'
    echo "$commits"
    echo '```'
  fi
  if [ -n "$changed" ]; then
    echo "**未コミットの変更:**"
    echo '```'
    echo "$changed"
    echo '```'
  fi
  if [ -z "$commits" ] && [ -z "$changed" ]; then
    echo "_(コミット・変更なし: ${repo}${branch:+ / ${branch}})_"
  fi
  echo ""
} > "$file" 2>/dev/null

exit 0
