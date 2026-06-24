#!/bin/bash
#
# guardrail / secret-guard
# PreToolUse(Write|Edit) フック。書き込み内容に高精度なシークレットパターンが
# 含まれる場合、PreToolUse の JSON 出力で「確認(ask)」を促す(ブロックはしない)。
# jq が無い環境では stderr 警告にフォールバックする。常に exit 0。
#
set -u

input="$(cat)"

if command -v jq >/dev/null 2>&1; then
  fp="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"
  # Write は content、Edit は new_string に新しい内容が入る。両方を結合して走査する。
  body="$(printf '%s' "$input" | jq -r '[.tool_input.content, .tool_input.new_string] | map(select(. != null)) | join("\n")' 2>/dev/null)"
else
  fp=""
  body="$input"
fi
scan="${body:-$input}"

# 高精度なシークレットパターンのみ検出(誤検知を抑えるため一般的すぎる形は含めない)
patterns='-----BEGIN [A-Z ]*PRIVATE KEY-----|AKIA[0-9A-Z]{16}|gh[opsur]_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{22,}|xox[baprs]-[A-Za-z0-9-]{10,}|AIza[0-9A-Za-z_-]{35}|sk-(ant-)?[A-Za-z0-9_-]{20,}|sk_live_[A-Za-z0-9]{16,}|glpat-[A-Za-z0-9_-]{20,}'

if printf '%s' "$scan" | grep -Eq -e "$patterns"; then
  loc=""
  [ -n "${fp:-}" ] && loc="対象: ${fp}。"
  reason="書き込み内容にシークレットらしき文字列(APIキー/トークン/秘密鍵)が含まれています。${loc}機密は直書きせず、環境変数や credential helper 経由で参照してください。"
  if command -v jq >/dev/null 2>&1; then
    jq -cn --arg r "$reason" \
      '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$r}}'
  else
    echo "⚠️ guardrail(secret): $reason" >&2
  fi
fi
exit 0
