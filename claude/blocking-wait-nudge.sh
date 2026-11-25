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

#
# The two IDLE predicates below cover what the shape-based ones cannot see,
# measured over 30 sessions (2026-11): one session spent 596 calls that were
# only `echo waiting` while a background job ran, and 251 calls re-read job
# output with tail/grep. Neither contains a loop or a long sleep.

set -u

payload=$(cat)
cmd=$(printf '%s' "$payload" | jq -r '.tool_input.command // ""' 2>/dev/null)
bg=$(printf '%s' "$payload" | jq -r '.tool_input.run_in_background // false' 2>/dev/null)
sid=$(printf '%s' "$payload" | jq -r '.session_id // ""' 2>/dev/null)

# Already backgrounded — that is exactly what this hook would ask for.
[ "$bg" = "true" ] && exit 0
[ -z "$cmd" ] && exit 0

nudge() {
  jq -n --arg msg "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      additionalContext: $msg
    },
    suppressOutput: true
  }'
  exit 0
}

# IDLE 1: every statement is a literal echo/printf, a sleep, `true` or `:`.
# `$` disqualifies a statement, so `echo $?` (the sanctioned exit-status read in
# worker-spec.template.md) stays silent; `>` disqualifies it as a file write.
idle=1
while IFS= read -r seg; do
  seg="${seg#"${seg%%[![:space:]]*}"}"
  [ -z "$seg" ] && continue
  case "$seg" in
    *'$'*|*'>'*|*'`'*) idle=0; break ;;
  esac
  printf '%s' "$seg" | grep -qE '^(echo|printf|sleep[[:space:]]+[0-9.]+[smh]?|true|:)([[:space:]]|$)' \
    || { idle=0; break; }
done < <(printf '%s\n' "$cmd" | sed -E 's/(&&|\|\||;)/\n/g')
if [ "$idle" -eq 1 ]; then
  nudge 'This Bash call only prints or sleeps; it does not wait on anything. A run_in_background job notifies you when it exits, and Monitor waits on a condition. Use one of those, or end the turn. One session spent 596 calls like this.'
fi

# IDLE 2: the same job-output file read again and again. Counted per session;
# fires on the 3rd read of one file and every 5th after that.
if [ -n "$sid" ] && printf '%s' "$cmd" | grep -qE '^[[:space:]]*(tail|grep|cat|head)\b'; then
  f=$(printf '%s' "$cmd" | grep -oE '[^[:space:]"'"'"']+\.(log|output|out)\b' | head -n 1)
  if [ -n "$f" ]; then
    state="${TMPDIR:-/tmp}/claude-reread-${sid//[^A-Za-z0-9_-]/}"
    n=$(( $(grep -cxF -- "$f" "$state" 2>/dev/null || true) + 1 ))
    printf '%s\n' "$f" >> "$state"
    if [ $(( n % 5 )) -eq 3 ]; then
      nudge "Read #$n of $f this session. A growing log is not progress: nix develop link warnings grew a log while nothing advanced. Wait for the job's completion notice, or arm Monitor on the line that means done/failed. Re-reads cost 251 calls over 30 sessions."
    fi
  fi
fi

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

nudge 'Foreground wait detected. Run it with run_in_background:true and wait on the condition with the Monitor tool instead — blocking waits were the largest measured time sink (12.8h over 8 weeks). If you genuinely need to block, carry on.'
