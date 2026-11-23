# shellcheck shell=bash
# lib.sh — helpers shared by the T5 grader scripts. Sourced, not executed.
#
# The reference is tasks/T5/solution/crates/steno-core/src/{format.rs,lib.rs}, an
# overlay onto the pinned anysteno tree. A broken variant is the reference with
# broken/<name>/mutate.sed applied to format.rs.

T5_GRADER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
T5_DIR="$(cd "$T5_GRADER/.." && pwd)"
T5_SRC=crates/steno-core/src

# t5_install_ref <tree> — the reference formatter (format.rs and the lib.rs re-export).
t5_install_ref() {
  install -D -m 0644 "$T5_DIR/solution/$T5_SRC/format.rs" "$1/$T5_SRC/format.rs" || return 1
  install -D -m 0644 "$T5_DIR/solution/$T5_SRC/lib.rs" "$1/$T5_SRC/lib.rs"
}

# t5_install_broken <name> <tree> — the reference with broken/<name>/mutate.sed applied.
# Fails when the edit changes nothing, so a variant can never silently be the reference.
t5_install_broken() {
  local m="$T5_GRADER/broken/$1/mutate.sed"
  [ -f "$m" ] || { echo "t5_install_broken: no $m" >&2; return 1; }
  t5_install_ref "$2" || return 1
  sed -f "$m" "$T5_DIR/solution/$T5_SRC/format.rs" > "$2/$T5_SRC/format.rs" || return 1
  if cmp -s "$T5_DIR/solution/$T5_SRC/format.rs" "$2/$T5_SRC/format.rs"; then
    echo "t5_install_broken: $1 changes nothing" >&2
    return 1
  fi
}

# t5_broken_names — every variant under grader/broken/, one per line.
t5_broken_names() {
  local d
  for d in "$T5_GRADER"/broken/*/; do
    [ -f "$d/mutate.sed" ] && basename "$d"
  done
}

# t5_cargo_env <scratch_dir> <workspace> — exports a private CARGO_HOME whose registry
# is the run's (the target of <workspace>.cargo/registry when there is one), so a grade
# never writes cargo's lock files next to the run.
t5_cargo_env() {
  local reg=""
  [ -L "$2.cargo/registry" ] && reg="$(readlink "$2.cargo/registry")"
  BENCH_CARGO_REGISTRY="${reg:-${BENCH_CARGO_REGISTRY:-$HOME/.cargo/registry}}" \
    repo_cargo_home "$1/cargo" || return 1
  export CARGO_HOME="$1/cargo" CARGO_NET_OFFLINE=true CARGO_TERM_COLOR=never
  unset CARGO_TARGET_DIR
}

# t5_hidden_count <cargo test output> — "<passed> <compiled>" for the hidden suite: the
# `test case_NNN ... ok` lines, and whether a test binary ran at all (a compile failure
# prints no `test result:` line, and then every case counts as failed).
t5_hidden_count() {
  local passed compiled=false
  passed="$(grep -cE '^test case_[0-9]+ \.\.\. ok$' "$1")"
  grep -q '^test result:' "$1" && compiled=true
  echo "$passed $compiled"
}
