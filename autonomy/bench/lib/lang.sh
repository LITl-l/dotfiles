# shellcheck shell=bash
# lang.sh — guess the implementation language an agent chose. Sourced, not executed.

# detect_lang <dir> — prints one of rust|go|node|python|c|bash|sh|unknown.
# Build manifests win over the ./run shebang: a compiled solution usually has a shell
# ./run that only execs the binary, and that wrapper is not the language chosen.
detect_lang() {
  local d="$1" shebang=""
  if [ -f "$d/Cargo.toml" ]; then echo rust; return; fi
  if [ -f "$d/go.mod" ]; then echo go; return; fi
  if [ -f "$d/package.json" ]; then echo node; return; fi
  if [ -f "$d/pyproject.toml" ] || [ -f "$d/requirements.txt" ]; then echo python; return; fi
  if [ -n "$(find "$d" -maxdepth 2 -name '*.c' -print -quit 2>/dev/null)" ]; then echo c; return; fi
  [ -f "$d/run" ] && IFS= read -r shebang < "$d/run"
  case "$shebang" in
    '#!'*python*) echo python ;;
    '#!'*node*)   echo node ;;
    '#!'*bash*)   echo bash ;;
    '#!'*/sh|'#!'*' sh') echo sh ;;
    *) echo unknown ;;
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
