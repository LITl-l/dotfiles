#!/usr/bin/env bash
# P1.stop-hook.sh <ws> — Claude Code Stop hook for bench part P1: the done gate.
#
# A Stop hook, not a PreToolUse one, because it sees the DONE file whichever tool wrote
# it (`touch DONE`, `: > DONE`, `cp`), with no Bash-string parsing to game.
#
#   no <ws>/DONE      exit 0: the stop is allowed
#   gate passes       exit 0, DONE kept
#   gate refuses      DONE removed; prints {"decision":"block","reason":…} so Claude goes on
#   6th refusal       DONE removed, the stop allowed (gate_exhausted)
#
# done-gate.sh itself hides DONE as DONE.pending while it runs, so a run killed mid-gate
# is left with no DONE; on a refusal this hook also removes a DONE.pending a killed gate
# left behind.
#
# Every verdict appends one line to <ws>.gate.jsonl, beside the workspace and outside the
# agent's write scope; run reads gate_refusals and gate_exhausted from it. stop_hook_active
# is ignored: the cap of 5 is already below Claude Code's own 8 consecutive continuations.
#
# The workspace comes from argv (run bakes it in as @WS@), not the hook input's cwd, which
# follows the session into a subdirectory. Hooks run unsandboxed as the user, so the gate,
# which runs agent code, runs under bwrap: no network, the workspace the only writable
# tree, and every checkout that holds a grader hidden under a tmpfs.
#
# Env: BENCH_GATE_BWRAP replaces the bwrap binary (the selftest's stand-in where user
# namespaces are unavailable).
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BENCH="$(dirname "$HERE")"
REPO="$(cd "$BENCH/../.." && pwd)"
GATE="$BENCH/lib/done-gate.sh"
CAP=5
GATE_BUDGET=380 # s; under the settings' hook timeout of 400, so a slow ./test is a refusal

input="$(cat)"
ws="${1:-}"
[ -n "$ws" ] || ws="$(jq -r '.cwd // empty' <<< "$input" 2> /dev/null)"
[ -n "$ws" ] && [ -d "$ws" ] || exit 0
ws="$(cd "$ws" && pwd)"
[ -f "$ws/DONE" ] || exit 0

ledger="$ws.gate.jsonl"
log() { # log <verdict> [reason]
  jq -cn --arg v "$1" --arg r "${2:-}" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{ts: $ts, agent: "claude", verdict: $v} + (if $r == "" then {} else {reason: $r} end)' \
    >> "$ledger"
}

hide=()
for r in "$REPO" "$HOME/.config/dotfiles" "$HOME/wkspace/worktree"; do
  [ -d "$r" ] && hide+=(--tmpfs "$r")
done
bw=("${BENCH_GATE_BWRAP:-bwrap}" --ro-bind / / --dev /dev --proc /proc --tmpfs /tmp
  "${hide[@]}" --bind "$ws" "$ws" --ro-bind "$GATE" /tmp/done-gate.sh
  --unshare-net --unshare-pid --die-with-parent --new-session --chdir "$ws"
  -- env TMPDIR=/tmp bash /tmp/done-gate.sh "$ws")

reason="$(timeout -k 10 "$GATE_BUDGET" "${bw[@]}" 2> "$ws.gate.err")"
rc=$?
if [ "$rc" -eq 0 ]; then
  log pass
  exit 0
fi
if [ "$rc" -eq 124 ] || [ "$rc" -eq 137 ]; then
  reason="The checker ran longer than ${GATE_BUDGET} s; ./test must finish faster."
elif [ -z "$reason" ]; then
  reason="The checker could not run (exit $rc): $(tail -c 300 "$ws.gate.err" | tr '\n' ' ')"
fi

rm -f "$ws/DONE" "$ws/DONE.pending" # the gate deletes DONE.pending itself unless it was killed
refusals="$(jq -s '[.[] | select(.verdict == "refused")] | length' "$ledger" 2> /dev/null)" || refusals=0
if [ "${refusals:-0}" -ge "$CAP" ]; then
  log exhausted "$reason"
  exit 0
fi
log refused "$reason"
jq -cn --arg r "$reason DONE was removed; fix and recreate it." '{decision: "block", reason: $r}'
