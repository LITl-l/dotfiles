# shellcheck shell=bash
# proc.sh — stop a process and everything it started. Sourced, not executed.
#
# A process group is not enough: `timeout` inside the llm adapter moves itself into its
# own group, and bwrap --new-session's child calls setsid. So the root is started with
# `setsid`, and its tree is the union of (1) its live descendants and (2) every process
# still in its session, which catches children orphaned after their parent died. Read
# from /proc, so it needs no procps.

# tree_pids <root_pid> — live pids in root's tree, one per line; zombies are left out
# (they cannot be signalled and their parent reaps them).
tree_pids() {
  local root="$1" f line pid rest state ppid sess changed p
  local -A parent=() want=()
  for f in /proc/[0-9]*/stat; do
    { IFS= read -r line < "$f"; } 2> /dev/null || continue
    pid="${f#/proc/}"
    pid="${pid%/stat}"
    rest="${line##*) }"   # comm may hold spaces or ')': cut after the last ') '
    read -r state ppid _ sess _ <<< "$rest"
    [ "$state" = Z ] && continue
    parent[$pid]="$ppid"
    if [ "$pid" = "$root" ] || [ "$sess" = "$root" ]; then want[$pid]=1; fi
  done
  changed=1
  while [ "$changed" -eq 1 ]; do
    changed=0
    for p in "${!parent[@]}"; do
      if [ -z "${want[$p]:-}" ] && [ -n "${want[${parent[$p]}]:-}" ]; then
        want[$p]=1
        changed=1
      fi
    done
  done
  for p in "${!want[@]}"; do
    [ "$p" = "$$" ] || [ "$p" = "$BASHPID" ] || echo "$p"
  done
}

# signal_tree <signal> <root_pid>
signal_tree() {
  local p
  for p in $(tree_pids "$2"); do kill -s "$1" "$p" 2> /dev/null; done
}

# reap_tree <root_pid> <grace_s> — TERM whatever is left of the tree, KILL what outlives
# the grace. Returns once nothing is left.
reap_tree() {
  local root="$1" grace="$2" i
  [ -n "$(tree_pids "$root")" ] || return 0
  signal_tree TERM "$root"
  for ((i = 0; i < grace * 5; i++)); do
    [ -n "$(tree_pids "$root")" ] || return 0
    sleep 0.2
  done
  signal_tree KILL "$root"
}

# watchdog <root_pid> <limit_s> <grace_s> <marker> — run in the background. At the limit
# it creates <marker>, TERMs the tree, and KILLs it after the grace. `sleep` is nanosleep
# on CLOCK_MONOTONIC, so a host suspend does not shorten the limit. TERM the watchdog to
# cancel it.
watchdog() {
  local root="$1" limit="$2" grace="$3" marker="$4" sp=""
  trap '[ -n "$sp" ] && kill "$sp" 2> /dev/null; exit 0' TERM
  sleep "$limit" & sp=$!
  wait "$sp"
  : > "$marker"
  signal_tree TERM "$root"
  sleep "$grace" & sp=$!
  wait "$sp"
  signal_tree KILL "$root"
}
