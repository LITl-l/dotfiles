# shellcheck shell=bash
# grader.sh — helpers for tasks/<T>/grader/grade. Sourced, not executed.
#
# A task grader prints exactly one JSON line to stdout:
#   {"passed":n,"total":n,"test_kill_rate":x|null,"perf_speedup":x|null,"mismatch":n,"errors":[...]}
# The bench `grade` entry adds task, hidden_pass and grader_s, and validates the shape.
# A task grader exits 0 whenever it could grade, including when every case fails.

# kill_rate <solution_dir> <reference_run> <broken_dir>...
# Prints the fraction of broken implementations the solution's own ./test fails on, or
# null when the solution ships no ./test. A ./test that already fails against the
# reference scores 0: failing on everything would otherwise kill every mutant for free.
kill_rate() {
  local sol="$1" ref="$2"; shift 2
  local n=0 killed=0 b
  if [ ! -e "$sol/test" ]; then echo null; return 0; fi
  if ! (cd "$sol" && BENCH_TARGET="$ref" timeout 60 ./test) > /dev/null 2>&1; then
    echo 0; return 0
  fi
  for b in "$@"; do
    n=$((n + 1))
    if ! (cd "$sol" && BENCH_TARGET="$b/run" timeout 60 ./test) > /dev/null 2>&1; then
      killed=$((killed + 1))
    fi
  done
  if [ "$n" -eq 0 ]; then echo null; return 0; fi
  jq -n --argjson k "$killed" --argjson n "$n" '$k / $n'
}

# run_io_cases <run_path> <cases.json> <err_file>
# cases.json is an array of {"name","in","out"}. Feeds each "in" to <run_path> on stdin
# and requires byte-exact stdout and exit 0. Prints the number passed; appends one line
# per failure to <err_file>.
run_io_cases() {
  local run="$1" cases="$2" errf="$3" n i name passed=0 dir
  dir="$(mktemp -d)"
  n="$(jq 'length' "$cases")"
  for ((i = 0; i < n; i++)); do
    name="$(jq -r ".[$i].name" "$cases")"
    jq -j ".[$i].in" "$cases" > "$dir/in"
    jq -j ".[$i].out" "$cases" > "$dir/want"
    if timeout 10 "$run" < "$dir/in" > "$dir/got" 2> /dev/null; then
      if cmp -s "$dir/got" "$dir/want"; then
        passed=$((passed + 1))
      else
        printf '%s: output mismatch\n' "$name" >> "$errf"
      fi
    else
      printf '%s: exit %s\n' "$name" "$?" >> "$errf"
    fi
  done
  rm -rf "$dir"
  echo "$passed"
}

# emit <passed> <total> <test_kill_rate|null> <perf_speedup|null> <mismatch> <err_file>
emit() {
  jq -cn --argjson p "$1" --argjson t "$2" --argjson k "$3" --argjson s "$4" \
    --argjson m "$5" --rawfile e "$6" \
    '{passed:$p, total:$t, test_kill_rate:$k, perf_speedup:$s, mismatch:$m,
      errors:($e | split("\n") | map(select(length > 0)))}'
}
