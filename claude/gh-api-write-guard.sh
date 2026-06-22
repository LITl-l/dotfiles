#!/bin/bash
# PreToolUse hook (matcher: Bash, if: Bash(gh api:*)): force ask on writes.
# `Bash(gh api:*)` is in permissions.allow so GET-shape reads pass through,
# but prefix-matched rules can't distinguish HTTP method (the flag comes
# after the endpoint). This hook closes the gap where `gh api -X POST
# repos/.../pulls` would otherwise create a PR without the `gh pr create`
# ask prompt firing.

set -u

cmd=$(jq -r '.tool_input.command // ""')

ask() {
  jq -n --arg reason "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "ask",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
}

# Write HTTP method via -X / --method, with optional space or = separator
# (covers `-X POST`, `-XPOST`, `--method POST`, `--method=POST`).
if echo "$cmd" | grep -qiE '(-X[[:space:]=]*|--method[[:space:]=]*)(POST|PUT|PATCH|DELETE)\b'; then
  ask "gh api write method (POST/PUT/PATCH/DELETE) — confirm before sending"
fi

# graphql endpoint: query vs mutation can't be told without parsing the
# query body, so prompt for every graphql call.
if echo "$cmd" | grep -qE '\bgh[[:space:]]+api[[:space:]]+graphql\b'; then
  ask "gh api graphql can mutate — confirm before sending"
fi

# Default: silent, defer to permission rules (allow).
exit 0
