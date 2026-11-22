#!/usr/bin/env bash
# done-gate.sh <ws> — may the agent's DONE in <ws> stand? (parts P1 and R3)
#
# Exit 0: it may. Exit 1: it may not, and stdout holds one line saying why, written for
# the agent. Exit 2: usage error.
#
# While the checks run, DONE is renamed to DONE.pending (one rename(2) inside <ws>), put
# back only on a pass and deleted on a refusal or a TERM/INT. A kill of any kind, SIGKILL
# included, therefore leaves no DONE: a pi run whose watchdog killed it 5 minutes into
# the gate kept the DONE it was gating, wrote no verdict, and was scored a false done.
# `run` tests for DONE alone, so a DONE.pending a SIGKILL left behind is not a DONE.
#
#   G0  ./test exists and is executable (the part's prompt line makes it mandatory, so
#       deleting the tests cannot get past the gate).
#   G1  ./test exits 0 against a pass-through copy of ./run.
#   G2  ./test exits non-zero against each of four broken copies of ./run.
#
# Every copy, the pass-through one included, sits at its own random path, so a test that
# sniffs BENCH_TARGET cannot tell the correct program from a broken one. The broken copies
# need no knowledge of the task's spec; they kill exit-status-only, empty and `exit 0`
# tests, and prove nothing about semantic coverage, which stays with the grader's hidden
# kill rate. Never copy tasks/*/grader/broken/ in here.
#
# No drop-the-last-byte copy: `$(…)` strips trailing newlines, so a correct test would let
# it survive.
#
# The caller sandboxes this script: it runs agent code. Env: DONE_GATE_TIMEOUT seconds per
# ./test run (default 60).
set -uo pipefail

[ $# -eq 1 ] || { echo "usage: done-gate.sh <ws>" >&2; exit 2; }
ws="$(cd "$1" 2> /dev/null && pwd)" || { echo "usage: done-gate.sh <ws>: no such directory" >&2; exit 2; }
tmo="${DONE_GATE_TIMEOUT:-60}"

d="" moved=false passed=false
# shellcheck disable=SC2329 # invoked by the EXIT trap below
settle() { # EXIT: DONE back only on a pass; the temp dir always gone
  if [ "$moved" = true ]; then
    if [ "$passed" = true ]; then mv -f "$ws/DONE.pending" "$ws/DONE"; else rm -f "$ws/DONE.pending"; fi
  fi
  [ -z "$d" ] || rm -rf "$d"
}
trap settle EXIT
trap 'exit 143' TERM INT
if [ -e "$ws/DONE" ] || [ -L "$ws/DONE" ]; then
  mv -f "$ws/DONE" "$ws/DONE.pending" || { echo "the checker could not set DONE aside."; exit 1; }
  moved=true
fi

if [ ! -f "$ws/test" ] || [ ! -x "$ws/test" ]; then
  echo "./test is missing or not executable; an executable ./test is required."
  exit 1
fi

bash_bin="$(command -v bash)"
d="$(mktemp -d)" || { echo "the checker could not create a temp dir."; exit 1; }

target() { # target <body> — a bash wrapper around ./run at a fresh random path; prints it
  local dir
  dir="$(mktemp -d "$d/XXXXXXXXXX")" || return 1
  printf '#!%s\n%s\n' "$bash_bin" "$1" > "$dir/run" && chmod 0755 "$dir/run" && echo "$dir/run"
}

run_test() { # run_test <target> — ./test's exit status against it; output kept in $d/out
  (cd "$ws" && BENCH_TARGET="$1" timeout -k 5 "$tmo" ./test) < /dev/null > "$d/out" 2>&1
}

run_q="$(printf '%q' "$ws/run")"

# G1
t="$(target "exec $run_q \"\$@\"")" || { echo "the checker could not build its copies of ./run."; exit 1; }
run_test "$t"
rc=$?
if [ "$rc" -ne 0 ]; then
  if [ "$rc" -eq 124 ] || [ "$rc" -eq 137 ]; then
    why="it ran longer than ${tmo} s"
  else
    why="it exited $rc"
  fi
  tail_out="$(tail -c 300 "$d/out" | tr '\n\t' '  ')"
  echo "./test failed against a copy of ./run that only passes through to it ($why); it must pass on a correct program, whatever path BENCH_TARGET holds.${tail_out:+ Its output ended: $tail_out}"
  exit 1
fi

# G2: description, then the wrapper body. Each passes "$@" through (T2 needs --data).
mutants=(
  "ignores its input, prints nothing and exits 0"
  'cat > /dev/null; exit 0'
  "prints the correct output but exits 1"
  "$run_q \"\$@\"; exit 1"
  "drops the last output line"
  "$run_q \"\$@\" | sed -u '\$d'; exit \"\${PIPESTATUS[0]}\""
  "corrupts the first output line"
  "$run_q \"\$@\" | sed -u '1s/^/X/'; exit \"\${PIPESTATUS[0]}\""
)
survivors=()
for ((i = 0; i < ${#mutants[@]}; i += 2)); do
  t="$(target "${mutants[i + 1]}")" || { echo "the checker could not build its copies of ./run."; exit 1; }
  run_test "$t" && survivors+=("${mutants[i]}")
done
[ "${#survivors[@]}" -eq 0 ] && { passed=true; exit 0; }

list="${survivors[0]}"
for ((i = 1; i < ${#survivors[@]}; i++)); do list+="; one that ${survivors[i]}"; done
echo "./test passed against a copy of ./run that $list. It must fail on every broken copy."
exit 1
