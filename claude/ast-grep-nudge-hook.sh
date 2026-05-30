#!/bin/bash
# PreToolUse hook (matcher: Grep): nudge toward ast-grep for STRUCTURAL code
# queries. Non-blocking — the Grep always runs; this only injects a one-line
# reminder via additionalContext that `ast-grep`/`sg` matches syntax (AST)
# while Grep matches text. ast-grep here parses nix, lua, sh, json, yaml, css;
# Grep stays the right tool for plain text (strings, comments, filenames, md).

set -u

# Drain stdin (the PreToolUse payload) so the writer never sees EPIPE. The
# nudge is static, so we don't inspect the search pattern.
cat >/dev/null

msg='Tip: for STRUCTURAL code queries (call sites, def/usage shapes, AST patterns) in nix/lua/sh/json/yaml/css, prefer ast-grep — `ast-grep -p <pattern> -l <lang>` (alias `sg`) matches syntax, not text. For plain-text matches (strings, comments, filenames, markdown), Grep is correct; carry on.'

jq -n --arg msg "$msg" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    additionalContext: $msg
  },
  suppressOutput: true
}'
