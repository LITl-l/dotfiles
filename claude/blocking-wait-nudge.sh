#!/bin/bash
# PreToolUse hook (matcher: Bash): nudge off FOREGROUND blocking waits.
# Non-blocking — the command always runs; this only injects a one-line reminder
# via additionalContext that a poll loop should be backgrounded and waited on
# with the Monitor tool instead of occupying the foreground.
#
# Measured over 8 weeks of this user's transcripts: blocking waits cost 12.8h
# (4.17h standalone + 8.68h embedded in gh/push commands) — the single largest
# actionable time sink.
#
# PREDICATE NOTE: `timeout <n>` was deliberately DROPPED. Replaying it over the
# corpus fired 866 times, almost all on `timeout 115 ./node_modules/.bin/vitest`
# — a safety cap on a bounded command, not an unbounded wait. The surviving
# predicate is shape-based: a loop paired with a sleep, an explicit gh watch, or
# a sleep too long to be a settle delay. That lands at 146 fires against a
# measured budget of ~144 real wait calls.

set -u

payload=$(cat)
cmd=$(printf '%s' "$payload" | jq -r '.tool_input.command // ""' 2>/dev/null)
bg=$(printf '%s' "$payload" | jq -r '.tool_input.run_in_background // false' 2>/dev/null)

# Already backgrounded — that is exactly what this hook would ask for.
[ "$bg" = "true" ] && exit 0
[ -z "$cmd" ] && exit 0

fire=0

# A poll loop: `until ... do sleep N; done` / `while ! ...; do sleep N; done`.
if printf '%s' "$cmd" | grep -qE '\b(until|while)\b' \
   && printf '%s' "$cmd" | grep -qE '\bsleep\b'; then
  fire=1
fi

# Explicit blocking watchers.
printf '%s' "$cmd" | grep -qE '\bgh[[:space:]]+run[[:space:]]+watch\b' && fire=1
printf '%s' "$cmd" | grep -qE '\bgh[[:space:]]+pr[[:space:]]+checks\b[^&;|]*--watch' && fire=1

# A bare sleep long enough that it is a wait, not a settle delay. Short sleeps
# (`sleep 2` after starting a server) are legitimate and stay silent.
if [ "$fire" -eq 0 ]; then
  for n in $(printf '%s' "$cmd" | grep -oE '\bsleep[[:space:]]+[0-9]+' | grep -oE '[0-9]+$'); do
    if [ "$n" -ge 30 ] 2>/dev/null; then fire=1; break; fi
  done
fi

[ "$fire" -eq 0 ] && exit 0

msg='Foreground wait detected. Run it with run_in_background:true and wait on the condition with the Monitor tool instead — blocking waits were the largest measured time sink (12.8h over 8 weeks). If you genuinely need to block, carry on.'

jq -n --arg msg "$msg" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    additionalContext: $msg
  },
  suppressOutput: true
}'
exit 0
