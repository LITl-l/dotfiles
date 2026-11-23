# shellcheck shell=bash
# lib.sh — helpers shared by the T4 grader scripts. Sourced, not executed.
#
# Case files (cases/M<k>.cases, examples.cases) hold one case per block:
#
#   === <name>
#   --- args          one argument per line
#   --- in            the journal; each line is taken with its \n
#   --- out           the exact expected stdout; nothing after it but the next ===
#
# `--- in -n` drops the final \n of the journal (a last line without a newline).

T4_GRADER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
T4_DIR="$(cd "$T4_GRADER/.." && pwd)"

# shellcheck disable=SC2016 # a jq program; $l, $x, $tag are jq variables
CASES_JQ='
  (split("\n") | if .[-1] == "" then .[:-1] else . end) as $l
  | reduce $l[] as $x ({cases: [], cur: null, sec: null};
      if ($x | startswith("=== ")) then
        .cases += (if .cur then [.cur] else [] end)
        | .cur = {name: ($tag + "/" + $x[4:]), milestone: $tag, args: [], in: "", out: "", nonl: false}
        | .sec = null
      elif $x == "--- args" then .sec = "args"
      elif $x == "--- in" then .sec = "in"
      elif $x == "--- in -n" then .sec = "in" | .cur.nonl = true
      elif $x == "--- out" then .sec = "out"
      elif .sec == "args" then .cur.args += [$x]
      elif .sec == "in" then .cur.in += $x + "\n"
      elif .sec == "out" then .cur.out += $x + "\n"
      else error("line outside a section: \($x)") end)
  | .cases + (if .cur then [.cur] else [] end)
  | map((if .nonl then .in |= rtrimstr("\n") else . end) | del(.nonl))'

# cases_json <tag> <file.cases> — the file as a JSON array of
# {name, milestone, args, in, out}; name is "<tag>/<block name>".
cases_json() {
  jq -Rs --arg tag "$1" "$CASES_JQ" "$2"
}

# install_ref <dst> — the reference solution, built, at <dst>/run.
install_ref() {
  mkdir -p "$1" || return 1
  install -m 0644 "$T4_DIR/solution/ledger.c" "$1/ledger.c" || return 1
  install -m 0755 "$T4_DIR/solution/run" "$1/run" || return 1
  "$1/run" check < /dev/null > /dev/null
}

# install_broken <name> <dst> — the reference with grader/broken/<name>/mutate.sed
# applied, built, at <dst>/run. Fails when the edit changes nothing or does not compile,
# so a variant can never silently be the reference.
install_broken() {
  local m="$T4_GRADER/broken/$1/mutate.sed"
  [ -f "$m" ] || { echo "install_broken: no $m" >&2; return 1; }
  mkdir -p "$2" || return 1
  sed -f "$m" "$T4_DIR/solution/ledger.c" > "$2/ledger.c" || return 1
  if cmp -s "$T4_DIR/solution/ledger.c" "$2/ledger.c"; then
    echo "install_broken: $1 changes nothing" >&2
    return 1
  fi
  install -m 0755 "$T4_DIR/solution/run" "$2/run" || return 1
  "$2/run" check < /dev/null > /dev/null
}

# broken_names — every variant under grader/broken/, one per line.
broken_names() {
  local d
  for d in "$T4_GRADER"/broken/*/; do
    [ -f "$d/mutate.sed" ] && basename "$d"
  done
}
