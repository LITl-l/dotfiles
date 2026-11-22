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
ROW_OPTIONAL_FIELDS='["source_present"]'

# SC2016: the $names below are jq variables, not shell ones.
# shellcheck disable=SC2034,SC2016
ROW_CHECK_JQ='
  def num01: type == "number" and . >= 0 and . <= 1;
  def nnum: type == "number" and . >= 0;
  def str: type == "string" and length > 0;
  def problem(cond; msg): if cond then empty else msg end;
  if type != "object" then ["row is not an object"] else
  ($fields | sort) as $want | (keys | sort) as $have |
  [ ($want - $have | map("missing field: " + .))[],
    ($have - $want - $optional | map("unknown field: " + .))[],
    problem(.run_id | str; "run_id must be a non-empty string"),
    problem(.ts | (str and test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z$")); "ts must be UTC ISO-8601 (YYYY-MM-DDTHH:MM:SSZ)"),
    problem(.agent | (str and test("^(claude|pi|fixture:.+)$")); "agent must be claude, pi or fixture:<dir>"),
    problem(.model | (. == null or str); "model must be a string or null"),
    problem(.harness_rev | (type == "object" and (keys == ["parts","plugin_rev"])
      and (.parts | type == "array" and all(.[]; str))
      and (.plugin_rev | (. == null or str))); "harness_rev must be {parts:[string], plugin_rev:string|null}"),
    problem(.task | (type == "string" and test("^T[0-3]$")); "task must be T0..T3"),
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
      "source_present must be a boolean when present")
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
  jq -r --argjson fields "$fields" --argjson optional "$ROW_OPTIONAL_FIELDS" "$prog | .[]" <<< "$1" \
    || echo "schema check failed to run (bug in lib/row.sh)"
}
