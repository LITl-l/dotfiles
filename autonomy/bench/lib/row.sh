# shellcheck shell=bash
# row.sh — the runs.jsonl row schema (design spec §2) and the llm-bench row schema.
# Sourced, not executed.
#
# ROW_CHECK_JQ evaluates to [] for a valid row, or to a list of problems. It is the one
# place the field list lives; `record` uses it on every append and on --check.

# shellcheck disable=SC2034  # used by the scripts that source this file
ROW_FIELDS='["run_id","ts","agent","model","harness_rev","task","rep","hidden_pass",
  "test_kill_rate","perf_speedup","false_done","blocked","timeout","wall_s","tokens",
  "tool_cpu_s","lang"]'
# Optional: allowed, never required. Rows recorded before a field existed stay valid,
# and they are never rewritten to add it.
# shellcheck disable=SC2034
ROW_OPTIONAL_FIELDS='["source_present","silent_stop","done_ok","gate_refusals","gate_exhausted",
  "ref_pass"]'
# T4 only: required on a T4 row, refused on any other, so T0..T3 rows keep their shape.
# shellcheck disable=SC2034
ROW_T4_FIELDS='["t4_milestones_reached","t4_milestone_t","t4_regressions","t4_prop_pass",
  "t4_perf_ok","t4_loc","t4_files","t4_fmt_clean","t4_lint_clean","t4_compactions"]'
# T5 only, the same way.
# shellcheck disable=SC2034
ROW_T5_FIELDS='["boundary_ok","t5_regress_ok","t5_hidden_compiled","t5_loc","t5_fmt_clean",
  "t5_lint_clean","t5_compactions"]'

# SC2016: the $names below are jq variables, not shell ones.
# shellcheck disable=SC2034,SC2016
ROW_CHECK_JQ='
  def num01: type == "number" and . >= 0 and . <= 1;
  def nnum: type == "number" and . >= 0;
  def str: type == "string" and length > 0;
  def problem(cond; msg): if cond then empty else msg end;
  def nint: type == "number" and . >= 0 and . == floor;
  def optbool: . == null or type == "boolean";
  if type != "object" then ["row is not an object"] else
  (.task == "T4") as $t4 | (.task == "T5") as $t5
  | ($fields + (if $t4 then $t4fields else [] end) + (if $t5 then $t5fields else [] end) | sort) as $want
  | (keys | sort) as $have |
  [ ($want - $have | map("missing field: " + .))[],
    ($have - $want - $optional | map(
      if ($t4 | not) and IN($t4fields[]) then "field only for T4 rows: " + .
      elif ($t5 | not) and IN($t5fields[]) then "field only for T5 rows: " + .
      else "unknown field: " + . end))[],
    problem(.run_id | str; "run_id must be a non-empty string"),
    problem(.ts | (str and test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z$")); "ts must be UTC ISO-8601 (YYYY-MM-DDTHH:MM:SSZ)"),
    problem(.agent | (str and test("^(claude|pi|fixture:.+)$")); "agent must be claude, pi or fixture:<dir>"),
    problem(.model | (. == null or str); "model must be a string or null"),
    problem(.harness_rev | (type == "object" and (keys == ["parts","plugin_rev"])
      and (.parts | type == "array" and all(.[]; str))
      and (.plugin_rev | (. == null or str))); "harness_rev must be {parts:[string], plugin_rev:string|null}"),
    problem(.task | (type == "string" and test("^T[0-5]$")); "task must be T0..T5"),
    problem(.rep | (type == "number" and . >= 1 and . == floor); "rep must be an integer >= 1"),
    problem(.hidden_pass | num01; "hidden_pass must be a number in 0..1"),
    problem(.test_kill_rate | (. == null or num01); "test_kill_rate must be null or in 0..1"),
    problem(.perf_speedup | (. == null or nnum); "perf_speedup must be null or a number >= 0"),
    problem(.false_done | type == "boolean"; "false_done must be a boolean"),
    problem(.blocked | type == "boolean"; "blocked must be a boolean"),
    problem(.timeout | type == "boolean"; "timeout must be a boolean"),
    problem(.wall_s | nnum; "wall_s must be a number >= 0"),
    problem(.tokens | (. == null or (nnum and . == floor)); "tokens must be null or an integer >= 0"),
    problem(.tool_cpu_s | (. == null or nnum); "tool_cpu_s must be null or a number >= 0"),
    problem(.lang | (. == null or str); "lang must be a string or null"),
    problem((has("source_present") | not) or (.source_present | type == "boolean");
      "source_present must be a boolean when present"),
    problem((has("silent_stop") | not) or (.silent_stop | . == null or type == "boolean");
      "silent_stop must be a boolean or null when present"),
    problem((has("done_ok") | not) or (.done_ok | type == "boolean");
      "done_ok must be a boolean when present"),
    problem((has("gate_refusals") | not) or (.gate_refusals | . == null or (nnum and . == floor));
      "gate_refusals must be null or an integer >= 0 when present"),
    problem((has("gate_exhausted") | not) or (.gate_exhausted | . == null or type == "boolean");
      "gate_exhausted must be a boolean or null when present"),
    problem((has("ref_pass") | not) or (.ref_pass | . == null or type == "boolean");
      "ref_pass must be a boolean or null when present"),
    (if $t4 then
      problem(.t4_milestones_reached | (nint and . <= 5); "t4_milestones_reached must be an integer in 0..5"),
      problem(.t4_milestone_t | (type == "object" and (keys == ["M1","M2","M3","M4","M5"])
        and all(.[]; . == null or nnum)); "t4_milestone_t must be {M1..M5: seconds or null}"),
      problem(.t4_regressions | nint; "t4_regressions must be an integer >= 0"),
      problem(.t4_prop_pass | num01; "t4_prop_pass must be a number in 0..1"),
      problem(.t4_perf_ok | type == "boolean"; "t4_perf_ok must be a boolean"),
      problem(.t4_loc | nint; "t4_loc must be an integer >= 0"),
      problem(.t4_files | nint; "t4_files must be an integer >= 0"),
      problem(.t4_fmt_clean | optbool; "t4_fmt_clean must be a boolean or null"),
      problem(.t4_lint_clean | optbool; "t4_lint_clean must be a boolean or null"),
      problem(.t4_compactions | (. == null or nint); "t4_compactions must be null or an integer >= 0")
    else empty end),
    (if $t5 then
      problem(.boundary_ok | optbool; "boundary_ok must be a boolean or null"),
      problem(.t5_regress_ok | type == "boolean"; "t5_regress_ok must be a boolean"),
      problem(.t5_hidden_compiled | type == "boolean"; "t5_hidden_compiled must be a boolean"),
      problem(.t5_loc | nint; "t5_loc must be an integer >= 0"),
      problem(.t5_fmt_clean | optbool; "t5_fmt_clean must be a boolean or null"),
      problem(.t5_lint_clean | optbool; "t5_lint_clean must be a boolean or null"),
      problem(.t5_compactions | (. == null or nint); "t5_compactions must be null or an integer >= 0")
    else empty end)
  ] end'

# llm-bench rows: one llama-bench `-o jsonl` line wrapped as {"kind":"llm-bench",
# "model":<id>,…} by `llm bench`. Only these fields are required; the rest of
# llama-bench's own fields are allowed through unchecked, not rejected as unknown,
# because that set changes between llama.cpp builds.
# shellcheck disable=SC2034
LLM_BENCH_FIELDS='["kind","model","n_threads","n_prompt","n_gen","avg_ts","stddev_ts"]'

# shellcheck disable=SC2034,SC2016
LLM_BENCH_CHECK_JQ='
  def nnum: type == "number" and . >= 0;
  def nint: nnum and . == floor;
  def str: type == "string" and length > 0;
  def problem(cond; msg): if cond then empty else msg end;
  if type != "object" then ["row is not an object"] else
  [ ($fields - keys | map("missing field: " + .))[],
    problem(.kind == "llm-bench"; "kind must be llm-bench"),
    problem(.model | str; "model must be a non-empty string"),
    problem(.n_threads | (nint and . >= 1); "n_threads must be an integer >= 1"),
    problem(.n_prompt | nint; "n_prompt must be an integer >= 0"),
    problem(.n_gen | nint; "n_gen must be an integer >= 0"),
    problem(.avg_ts | nnum; "avg_ts must be a number >= 0"),
    problem(.stddev_ts | nnum; "stddev_ts must be a number >= 0")
  ] end'

# row_kind <json-line> — "runs" for a row without "kind", else the kind's value.
row_kind() {
  jq -r 'if type == "object" and has("kind") then (.kind | tostring) else "runs" end' <<< "$1"
}

# row_problems <json-line> — prints one problem per line; empty output means valid.
# Input parsing is checked separately from the schema program, so a bug in a check
# program surfaces as a jq error instead of being misreported as a bad row.
row_problems() {
  if ! jq -e 'true' <<< "$1" > /dev/null 2>&1; then
    echo "row is not valid JSON"
    return
  fi
  local fields prog
  case "$(row_kind "$1")" in
    runs) fields="$ROW_FIELDS" prog="$ROW_CHECK_JQ" ;;
    llm-bench) fields="$LLM_BENCH_FIELDS" prog="$LLM_BENCH_CHECK_JQ" ;;
    *) echo "unknown kind: $(row_kind "$1") (expected llm-bench, or no kind for a runs row)"; return ;;
  esac
  jq -r --argjson fields "$fields" --argjson optional "$ROW_OPTIONAL_FIELDS" \
    --argjson t4fields "$ROW_T4_FIELDS" --argjson t5fields "$ROW_T5_FIELDS" "$prog | .[]" <<< "$1" \
    || echo "schema check failed to run (bug in lib/row.sh)"
}
