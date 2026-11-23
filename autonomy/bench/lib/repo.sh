# shellcheck shell=bash
# repo.sh — the "repo" task kind: a workspace cloned from an existing repository instead
# of populated from a bench-owned skeleton. Sourced, not executed. Needs jj and jq.
#
# tasks/<T>/repo.json is {"src": <clone URL>, "branch": <branch to fetch>, "rev": <full
# commit id>}. A clone, never `jj workspace add`: a workspace would share the source's
# .jj/repo, so the agent's jj (and the grader's snapshot of a copy) would write the
# owner's operation log and reach their bookmarks. The clone reads the source's git store
# once and fetches one branch, then cuts it back to rev so later commits stay invisible.

# jj without a user config prints an identity warning on every command; the bench needs
# no identity (nothing is pushed), so commits carry this one.
REPO_JJ=(jj --quiet --no-pager --config user.name=bench --config user.email=bench@localhost)

# repo_install <task_dir> <ws> — clone the task's repository into <ws>, check out a new
# change on top of the pinned rev, drop the remote, record the rev in <ws>.base, install
# <task_dir>/overlay over the tree and give it a CARGO_HOME at <ws>.cargo.
repo_install() {
  local task_dir="$1" ws="$2" spec src branch rev
  spec="$task_dir/repo.json"
  src="$(jq -er '.src | select(type == "string" and length > 0)' "$spec")" \
    || { echo "repo_install: $spec has no src" >&2; return 1; }
  branch="$(jq -er '.branch | select(type == "string" and length > 0)' "$spec")" \
    || { echo "repo_install: $spec has no branch" >&2; return 1; }
  rev="$(jq -er '.rev | select(type == "string" and test("^[0-9a-f]{40}$"))' "$spec")" \
    || { echo "repo_install: $spec needs a full 40-hex rev" >&2; return 1; }
  [ -e "$ws" ] && { echo "repo_install: $ws already exists" >&2; return 1; }
  mkdir -p "$(dirname "$ws")" || return 1
  "${REPO_JJ[@]}" git clone --branch "$branch" "$src" "$ws" > /dev/null || return 1
  "${REPO_JJ[@]}" -R "$ws" new "$rev" > /dev/null || return 1
  "${REPO_JJ[@]}" -R "$ws" git remote remove origin > /dev/null || return 1
  # The fetched branch may have moved past rev; anything after rev must not reach the
  # agent. Pin the bookmark back to rev, so later commits become hidden, then drop the
  # operations that recorded them and prune their objects.
  "${REPO_JJ[@]}" -R "$ws" bookmark set "$branch" -r "$rev" --allow-backwards > /dev/null \
    || return 1
  "${REPO_JJ[@]}" -R "$ws" op abandon '..@-' > /dev/null || return 1
  "${REPO_JJ[@]}" -R "$ws" util gc --expire=now > /dev/null || return 1
  # The clone must stand on exactly the pinned tree, whatever the branch has become.
  [ "$("${REPO_JJ[@]}" -R "$ws" log --no-graph -r '@-' -T commit_id)" = "$rev" ] \
    || { echo "repo_install: $ws is not on $rev" >&2; return 1; }
  [ -z "$("${REPO_JJ[@]}" -R "$ws" log --no-graph -r 'all() ~ ::@' -T commit_id)" ] \
    || { echo "repo_install: $ws shows commits beyond $rev" >&2; return 1; }
  printf '%s\n' "$rev" > "$ws.base" || return 1
  if [ -d "$task_dir/overlay" ]; then
    install_tree "$task_dir/overlay" "$ws" || return 1
  fi
  repo_cargo_home "$ws.cargo"
}

# repo_cargo_home <dir> — a CARGO_HOME whose registry is a symlink to the user's
# (BENCH_CARGO_REGISTRY, default ~/.cargo/registry). Under the P0 sandbox the link is
# readable and its target is not writable; cargo's lock files land in <dir> itself.
repo_cargo_home() {
  local reg="${BENCH_CARGO_REGISTRY:-$HOME/.cargo/registry}"
  [ -d "$reg" ] || { echo "repo_cargo_home: no cargo registry at $reg" >&2; return 1; }
  mkdir -p "$1" || return 1
  [ -L "$1/registry" ] || ln -s "$reg" "$1/registry"
}

# repo_devpath <bench_repo> — a PATH holding cargo, rustc, rustfmt and clippy, for the
# session's settings (@DEVPATH@). BENCH_DEVPATH overrides it. The bench devShell, not
# the cloned repo's own: a repo without a committed flake.lock (anysteno's main) resolves
# a fresh nixpkgs and cannot evaluate offline, and `nix develop` there would also write a
# flake.lock into the agent's tree.
repo_devpath() {
  if [ -n "${BENCH_DEVPATH:-}" ]; then printf '%s\n' "$BENCH_DEVPATH"; return 0; fi
  nix develop "$1#bench" --offline --command printenv PATH 2> /dev/null
}
