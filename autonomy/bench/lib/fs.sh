# shellcheck shell=bash
# fs.sh — file helpers shared by the bench scripts. Sourced, not executed.

# install_tree <src_dir> <dst_dir>
# Copies every regular file under src into dst, keeping relative paths and modes.
# `install` rather than `cp -R`: an existing dst file is replaced, never merged into, and
# a symlink in a fixture cannot make a later write land outside the workspace.
install_tree() {
  local src="$1" dst="$2" rel mode
  [ -d "$src" ] || { printf 'install_tree: not a directory: %s\n' "$src" >&2; return 1; }
  mkdir -p "$dst"
  while IFS= read -r -d '' rel; do
    rel="${rel#./}"
    mode="$(stat -c %a "$src/$rel")"
    install -D -m "$mode" "$src/$rel" "$dst/$rel" || return 1
  done < <(cd "$src" && find . -type f -print0)
}
