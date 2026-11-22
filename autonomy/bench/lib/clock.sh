# shellcheck shell=bash
# clock.sh — a clock that a host suspend does not move. Sourced, not executed.
#
# Bash's $EPOCHREALTIME and $SECONDS and coreutils `date` follow CLOCK_REALTIME, and
# /proc/uptime is CLOCK_BOOTTIME, which counts suspended time: across a Windows
# sleep -> hibernate, a pi run's wall_s read 50586 s against a 3540 s limit. Only
# CLOCK_MONOTONIC is meant to stop while the machine sleeps, and bash cannot read it
# itself, so an interpreter does. Neither python3 nor perl is global here (D12); the
# .#bench devShell has python3, where every real run happens.

# mono_now — prints CLOCK_MONOTONIC seconds; returns 1 when nothing can read it.
mono_now() {
  if command -v python3 > /dev/null 2>&1; then
    # -I: never import a planted module from the cwd, which may be an agent's workspace.
    python3 -I -S -c 'import time; print("%.6f" % time.monotonic())' 2> /dev/null && return 0
  fi
  if command -v perl > /dev/null 2>&1; then
    perl -MTime::HiRes=clock_gettime,CLOCK_MONOTONIC \
      -e 'printf "%.6f\n", clock_gettime(CLOCK_MONOTONIC)' 2> /dev/null && return 0
  fi
  return 1
}
