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
