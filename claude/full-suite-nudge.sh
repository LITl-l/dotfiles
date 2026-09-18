#!/bin/bash
# Dual-event hook for REPEATED full-suite verification runs.
#
#   PreToolUse  (matcher: Bash)               -> detect an unscoped full-suite run
#   PostToolUse (matcher: Edit|Write|...)     -> count edits since the last one
#
# This is a SCOPING nudge, never a SKIPPING one. Measured over 8 weeks: full-suite
# runs cost 12.22h across 1,009 calls, and 11.78h of that (96%) is the 2nd-and-later
# run inside the SAME session; median edits since the previous full run = 1, and
# 19.1% of repeats had ZERO edits. But those same runs still surface a real failure
# 22.3% of the time — so the nudge asks for a NARROWER run, and "one full suite
# before the PR" stays mandatory.
#
# The first full run in a session is always silent, and so is one that follows
# substantial editing; only a near-duplicate repeat is nudged, at most once per
# editing streak. That keeps this at ~1 nudge per affected session rather than one
# per call — hook-injected text is not free (Stop-hook feedback alone cost ~11.9h
# of extra turns over the same window).

set -u

# N = edits since the last full run at or below which a repeat looks redundant.
WINDOW=${CLAUDE_NUDGE_EDIT_WINDOW:-2}
# streak = re-arm after substantial editing; session = at most once per session;
# none = no gate (used only to measure the raw predicate rate).
GATE=${CLAUDE_NUDGE_GATE:-streak}

payload=$(cat)
event=$(printf '%s' "$payload" | jq -r '.hook_event_name // ""' 2>/dev/null)
sid=$(printf '%s' "$payload" | jq -r '.session_id // ""' 2>/dev/null)
[ -z "$sid" ] && exit 0
sid=$(printf '%s' "$sid" | tr -c 'A-Za-z0-9._-' '_')

state_dir=${CLAUDE_NUDGE_STATE:-${XDG_CACHE_HOME:-$HOME/.cache}/claude-nudge}
mkdir -p "$state_dir" 2>/dev/null || exit 0
f="$state_dir/$sid"

runs=0; edits=0; armed=1
if [ -r "$f" ]; then
  read -r runs edits armed < "$f" 2>/dev/null || true
  [ -z "${runs:-}"  ] && runs=0
  [ -z "${edits:-}" ] && edits=0
  [ -z "${armed:-}" ] && armed=1
fi

save() { printf '%s %s %s\n' "$1" "$2" "$3" > "$f" 2>/dev/null || true; }

# ---------------- PostToolUse: count edits ----------------
if [ "$event" = "PostToolUse" ]; then
  save "$runs" "$((edits + 1))" "$armed"
  exit 0
fi

# ---------------- PreToolUse: detect a full-suite run ----------------
cmd=$(printf '%s' "$payload" | jq -r '.tool_input.command // ""' 2>/dev/null)
[ -z "$cmd" ] && exit 0

# Tokens that only wrap the real command; the runner may sit behind any of them
# (`uv run pytest`, `npx vitest`, `nix develop --command bash -c '... pytest'`).
is_wrapper() {
  case "$1" in
    uv|uvx|npx|poetry|pdm|hatch|bunx|bun|time|sudo|env|nix|pnpm|yarn|npm\
    |python|python3|node|command|exec|xargs|bash|sh|zsh|timeout|nice|stdbuf\
    |run|develop) return 0 ;;
  esac
  return 1
}

# A bare directory name that means "scope to this subtree".
is_dirword() {
  case "$1" in
    tests|test|spec|specs|src|lib|app|e2e|integration|unit) return 0 ;;
  esac
  return 1
}

unquote() { local t=$1; t=${t#[\"\']}; t=${t%[\"\']}; printf '%s' "$t"; }

# Returns 0 if this single segment is an UNSCOPED full-suite invocation.
segment_is_full_suite() {
  local seg=$1
  local -a toks=()
  read -ra toks <<< "$seg"
  local n=${#toks[@]} i=0 tok base
  [ "$n" -eq 0 ] && return 1

  while [ "$i" -lt "$n" ]; do
    tok=$(unquote "${toks[$i]}")
    case "$tok" in
      ''|*=*|-*) i=$((i + 1)); continue ;;
    esac
    case "$tok" in
      *[!0-9]*) ;;
      *) i=$((i + 1)); continue ;;   # a bare number (timeout duration)
    esac
    base=${tok##*/}
    if is_wrapper "$base"; then i=$((i + 1)); continue; fi
    break
  done
  [ "$i" -ge "$n" ] && return 1

  tok=$(unquote "${toks[$i]}")
  local runner=${tok##*/}
  local -a rest=()
  [ $((i + 1)) -lt "$n" ] && rest=("${toks[@]:$((i + 1))}")

  case "$runner" in
    test) runner="npm test" ;;
    flake)
      if [ "${#rest[@]}" -gt 0 ] && [ "$(unquote "${rest[0]}")" = "check" ]; then
        runner="nix flake check"; rest=("${rest[@]:1}")
      else return 1; fi ;;
    pytest|vitest|jest|tsc|eslint|oxlint) ;;
    ruff)
      if [ "${#rest[@]}" -gt 0 ]; then
        case "$(unquote "${rest[0]}")" in
          check|format) rest=("${rest[@]:1}") ;;
          *) return 1 ;;
        esac
      else return 1; fi ;;
    *) return 1 ;;
  esac

  if [ "$runner" = "vitest" ] && [ "${#rest[@]}" -gt 0 ] \
     && [ "$(unquote "${rest[0]}")" = "run" ]; then
    rest=("${rest[@]:1}")
  fi

  local t
  for t in ${rest[@]+"${rest[@]}"}; do
    t=$(unquote "$t")
    case "$t" in
      -k|-k=*|-m|-m=*|--filter|--filter=*|-t|-t=*|--grep|--grep=*\
      |--testNamePattern|--testNamePattern=*|--test-name-pattern|--test-name-pattern=*\
      |--testPathPattern|--testPathPattern=*|--project|--project=*|--projects|--projects=*\
      |--dir|--dir=*|--workspace|--workspace=*) return 1 ;;
      *::*) return 1 ;;
      -*) continue ;;
      .|./) continue ;;
      [0-9]*[\<\>]*|[\<\>]*) continue ;;
      */*) return 1 ;;
      *.py|*.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.nix|*.lua|*.go|*.rs) return 1 ;;
    esac
    if is_dirword "$t"; then return 1; fi
  done
  return 0
}

matched=1
while IFS= read -r seg; do
  if segment_is_full_suite "$seg"; then matched=0; break; fi
done <<< "$(printf '%s' "$cmd" | sed -E 's/&&|\|\||;|\|/\n/g')"

[ "$matched" -ne 0 ] && exit 0

# ---- a full-suite run: decide whether it is a redundant repeat ----
if [ "$runs" -eq 0 ]; then
  save 1 0 1          # first full run of the session is always silent
  exit 0
fi

if [ "$edits" -gt "$WINDOW" ]; then
  # Substantial editing since the last full run — a re-run is warranted.
  if [ "$GATE" = "streak" ]; then armed=1; fi
  save "$((runs + 1))" 0 "$armed"
  exit 0
fi

if [ "$GATE" != "none" ] && [ "$armed" -ne 1 ]; then
  save "$((runs + 1))" 0 "$armed"
  exit 0
fi

save "$((runs + 1))" 0 0

msg="Repeat full-suite run with ${edits} edit(s) since the last one. Full suites still fail 22.3% of the time, so keep verifying — but scope this run to what changed (-k / -m / a path) and save one full run for just before the PR. Let CI be the real gate."

jq -n --arg msg "$msg" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    additionalContext: $msg
  },
  suppressOutput: true
}'
exit 0
