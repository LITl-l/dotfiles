#!/bin/bash
# PreToolUse hook (matcher: Bash, if: Bash(grep:*) / Bash(rg:*)): nudge toward
# ast-grep for STRUCTURAL code queries. Non-blocking — the search always runs;
# this only injects a one-line reminder that `ast-grep`/`sg` matches syntax (AST)
# while grep matches text. ast-grep here parses nix, lua, sh, json, yaml, css;
# grep stays the right tool for plain text (strings, comments, filenames, md).
#
# MATCHER HISTORY: this hook used matcher `Grep` and fired ZERO times in 8 weeks —
# native Grep/Glob tool calls are 0 corpus-wide, because all search work goes
# through Bash. Retargeted to Bash with an `if:` command filter (the pattern
# gh-api-write-guard.sh uses).
#
# Retargeting alone would make it fire on all 713 leading grep/rg calls in the
# corpus, which is the chatty-nudge failure this whole change set exists to avoid.
# It is therefore gated to ONCE PER SESSION: 64 fires over the same 8 weeks.

set -u

payload=$(cat)
sid=$(printf '%s' "$payload" | jq -r '.session_id // ""' 2>/dev/null)
[ -z "$sid" ] && exit 0
sid=$(printf '%s' "$sid" | tr -c 'A-Za-z0-9._-' '_')

state_dir=${CLAUDE_NUDGE_STATE:-${XDG_CACHE_HOME:-$HOME/.cache}/claude-nudge}
mkdir -p "$state_dir" 2>/dev/null || exit 0
marker="$state_dir/$sid.astgrep"

# Already nudged in this session — stay silent.
[ -e "$marker" ] && exit 0
: > "$marker" 2>/dev/null || exit 0

msg='Tip: for STRUCTURAL code queries (call sites, def/usage shapes, AST patterns) in nix/lua/sh/json/yaml/css, prefer ast-grep — `ast-grep -p <pattern> -l <lang>` (alias `sg`) matches syntax, not text. For plain-text matches (strings, comments, filenames, markdown), grep is correct; carry on. (Shown once per session.)'

jq -n --arg msg "$msg" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    additionalContext: $msg
  },
  suppressOutput: true
}'
exit 0
