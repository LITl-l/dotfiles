# shellcheck shell=bash
# lang.sh — guess the implementation language an agent chose. Sourced, not executed.

# detect_lang <dir> — prints one of rust|go|node|python|c|bash|sh|unknown.
# Build manifests win over the ./run shebang: a compiled solution usually has a shell
# ./run that only execs the binary, and that wrapper is not the language chosen. For the
# same reason a ./run that is a trivial exec wrapper is followed to its target.
detect_lang() {
  local d="$1" l
  if [ -f "$d/Cargo.toml" ]; then echo rust; return; fi
  if [ -f "$d/go.mod" ]; then echo go; return; fi
  if [ -f "$d/package.json" ]; then echo node; return; fi
  if [ -f "$d/pyproject.toml" ] || [ -f "$d/requirements.txt" ]; then echo python; return; fi
  if [ -n "$(find "$d" -maxdepth 2 -name '*.c' -print -quit 2>/dev/null)" ]; then echo c; return; fi
  [ -f "$d/run" ] || { echo unknown; return; }
  if l="$(exec_wrapper_lang "$d")"; then echo "$l"; return; fi
  file_lang "$d/run"
}

# interp_lang <command> — the language an interpreter name runs; fails for any other.
interp_lang() {
  case "${1##*/}" in
    python|python[0-9]*|pypy*) echo python ;;
    node|nodejs|bun|deno) echo node ;;
    bash) echo bash ;;
    sh|dash) echo sh ;;
    *) return 1 ;;
  esac
}

# file_lang <file> — the language of a script, by its shebang, else by its extension.
file_lang() {
  local f="$1" shebang="" w
  IFS= read -r shebang < "$f" 2> /dev/null
  if [ "${shebang#\#!}" != "$shebang" ]; then
    read -r -a w <<< "${shebang#\#!}"
    # #!/usr/bin/env [-S] <interp>: the interpreter is the first word that is not env or a flag.
    for shebang in "${w[@]}"; do
      case "${shebang##*/}" in env|-*) continue ;; esac
      interp_lang "$shebang" || echo unknown
      return
    done
  fi
  case "$f" in
    *.py) echo python ;;
    *.js|*.mjs|*.ts) echo node ;;
    *.bash) echo bash ;;
    *.sh) echo sh ;;
    *) echo unknown ;;
  esac
}

# exec_wrapper_lang <dir> — when <dir>/run's only command (comments and blank lines
# aside) is `exec <interp> <file> [args]` or `exec ./<file> [args]`, with <file> in
# <dir>, prints the language of that target; fails otherwise, and for a target of no
# known language (a binary keeps the old answer, the wrapper's). The script's own directory
# may be written "$(dirname "$0")/" or "$(dirname "${BASH_SOURCE[0]}")/" instead of ./.
exec_wrapper_lang() {
  local d="$1" line f
  local -a w
  line="$(grep -vE '^[[:space:]]*(#|$)' "$d/run" 2> /dev/null)" || return 1
  case "$line" in *$'\n'*) return 1 ;; esac
  # shellcheck disable=SC2016 # a sed program matching a literal $(dirname $0)
  line="$(sed -E 's/["'\'']//g; s#\$\(dirname \$(0|\{0\}|\{BASH_SOURCE\[0\]\})\)/#./#g' <<< "$line")"
  read -r -a w <<< "$line"
  [ "${w[0]:-}" = exec ] || return 1
  case "${w[1]:-}" in
    ./*)
      f="${w[1]#./}"; [ -f "$d/$f" ] || return 1
      f="$(file_lang "$d/$f")"; [ "$f" != unknown ] || return 1
      echo "$f" ;;
    *)
      f="${w[2]:-}"; f="${f#./}"
      [ -n "$f" ] && [ -f "$d/$f" ] || return 1
      interp_lang "${w[1]:-}" ;;
  esac
}

# Extensions counted as reviewable source by source_present. detect_lang above keys on
# build manifests and the shebang, not on extensions, so this is the only such table.
# shellcheck disable=SC2034  # read by source_present
SOURCE_EXTS=(c h cc cpp cxx hpp rs go zig py ts js java kt hs ml nim d sh)

# source_present <dir> — prints false when <dir>/run is an ELF binary and no file with a
# SOURCE_EXTS extension exists at any depth outside .claude/; true otherwise. A result
# that is only a binary scores like any other, but nobody can review or rebuild it.
source_present() {
  local d="$1" magic="" e
  local -a names=()
  [ -f "$d/run" ] && magic="$(LC_ALL=C head -c 4 "$d/run" 2> /dev/null | tr -d '\0')"
  if [ "$magic" != $'\x7fELF' ]; then echo true; return; fi
  for e in "${SOURCE_EXTS[@]}"; do names+=(-o -name "*.$e"); done
  if [ -n "$(find "$d" -path "$d/.claude" -prune -o -type f \( "${names[@]:1}" \) -print -quit 2> /dev/null)" ]; then
    echo true
  else
    echo false
  fi
}
