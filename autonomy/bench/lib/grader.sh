# shellcheck shell=bash
# grader.sh — helpers for tasks/<T>/grader/grade. Sourced, not executed.
#
# A task grader prints exactly one JSON line to stdout:
#   {"passed":n,"total":n,"test_kill_rate":x|null,"ref_pass":b|null,"perf_speedup":x|null,
#    "mismatch":n,"errors":[...]}
# The bench `grade` entry adds task, hidden_pass and grader_s, and validates the shape.
# A task grader exits 0 whenever it could grade, including when every case fails.

# Seconds per ./test invocation against the reference and each broken copy. 180, not the
# old 60: a T2 ./test that was sound timed out at 60 s against the slow reference store and
# scored kill rate 0, as if it were weak.
BENCH_TEST_TIMEOUT="${BENCH_TEST_TIMEOUT:-180}"

# kill_rate <solution_dir> <reference_run> <broken_dir>...
# Prints {"test_kill_rate":x|null,"ref_pass":b|null}: the fraction of broken
# implementations the solution's own ./test fails on, and whether that ./test passed
# against the reference; both null when the solution ships no ./test. A ./test that
# already fails against the reference scores 0: failing on everything would otherwise
# kill every mutant for free. ref_pass false tells that 0 apart from a weak test's 0: the
# test was stricter than SPEC (or slower than the timeout) on a correct program.
kill_rate() {
  local sol="$1" ref="$2"; shift 2
  local n=0 killed=0 b
  local tmo="$BENCH_TEST_TIMEOUT"
  if [ ! -e "$sol/test" ]; then echo '{"test_kill_rate":null,"ref_pass":null}'; return 0; fi
  if ! (cd "$sol" && BENCH_TARGET="$ref" timeout "$tmo" ./test) > /dev/null 2>&1; then
    echo '{"test_kill_rate":0,"ref_pass":false}'; return 0
  fi
  for b in "$@"; do
    n=$((n + 1))
    if ! (cd "$sol" && BENCH_TARGET="$b/run" timeout "$tmo" ./test) > /dev/null 2>&1; then
      killed=$((killed + 1))
    fi
  done
  jq -cn --argjson k "$killed" --argjson n "$n" \
    '{test_kill_rate: (if $n == 0 then null else $k / $n end), ref_pass: true}'
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

# emit <passed> <total> <kill_rate's object> <perf_speedup|null> <mismatch> <err_file>
emit() {
  jq -cn --argjson p "$1" --argjson t "$2" --argjson k "$3" --argjson s "$4" \
    --argjson m "$5" --rawfile e "$6" \
    '{passed:$p, total:$t, test_kill_rate:$k.test_kill_rate, ref_pass:$k.ref_pass,
      perf_speedup:$s, mismatch:$m,
      errors:($e | split("\n") | map(select(length > 0)))}'
}
