{ config, pkgs, lib, ... }:

let
  dotfilesPath = "/home/nixos/.config/dotfiles";
  dotfilesClaudePath = "${dotfilesPath}/claude";
  mkSymlink = config.lib.file.mkOutOfStoreSymlink;
in
{
  # Config Claude Code only READS. home.file's out-of-store symlink is right for
  # these: an edit in the repo is live without a rebuild, and nothing ever writes
  # back through the link. Config Claude Code WRITES cannot use this -- see
  # linkClaudeWritableConfig below.
  home.file.".claude/stop-hook-git-check.sh".source = mkSymlink "${dotfilesClaudePath}/stop-hook-git-check.sh";
  home.file.".claude/stop-phrase-guard.sh".source = mkSymlink "${dotfilesClaudePath}/stop-phrase-guard.sh";
  home.file.".claude/wsl-clipboard-image-hook.sh".source = mkSymlink "${dotfilesClaudePath}/wsl-clipboard-image-hook.sh";
  home.file.".claude/ast-grep-nudge-hook.sh".source = mkSymlink "${dotfilesClaudePath}/ast-grep-nudge-hook.sh";
  home.file.".claude/gh-api-write-guard.sh".source = mkSymlink "${dotfilesClaudePath}/gh-api-write-guard.sh";
  home.file.".claude/blocking-wait-nudge.sh".source = mkSymlink "${dotfilesClaudePath}/blocking-wait-nudge.sh";
  home.file.".claude/full-suite-nudge.sh".source = mkSymlink "${dotfilesClaudePath}/full-suite-nudge.sh";

  # Meta-agent orchestration: the orchestrator agent definition and the worker spec
  # template it fills in. `--agent meta` constrains the TOP-LEVEL session (verified), so
  # the orchestrator has no Edit/Write and cannot drift into implementing things itself.
  home.file.".claude/agents/meta.md".source = mkSymlink "${dotfilesClaudePath}/agents/meta.md";
  home.file.".claude/worker-spec.template.md".source = mkSymlink "${dotfilesClaudePath}/worker-spec.template.md";

  # `fleet` manages background agent sessions. Unlike the files above it is installed INTO
  # the store rather than symlinked out of it: an out-of-store symlink dangles on any
  # machine without this checkout, and a sandboxed build stats its inputs, so CI cannot
  # realise it. The trade-off is that editing scripts/fleet needs a rebuild.
  home.packages = [
    (pkgs.writeTextFile {
      name = "fleet";
      destination = "/bin/fleet";
      executable = true;
      text = builtins.readFile ../scripts/fleet;
    })
  ];

  # settings.json and CLAUDE.md are the two files Claude Code writes BACK -- the
  # permission prompts and /permissions rewrite settings.json, `#` and /remember
  # rewrite the user-scope CLAUDE.md -- and it writes them atomically: temp file in
  # the target's directory, then rename() over the target.
  #
  # home.file cannot host such a file. Its out-of-store symlink is always a TWO-hop
  # chain, because the generation's store directory is the mechanism:
  #
  #   ~/.claude/settings.json
  #     -> /nix/store/<hash>-home-manager-files/.claude/settings.json   (dir is r-xr-xr-x, root)
  #     -> <repo>/claude/settings.json
  #
  # The atomic writer resolves only the FIRST hop and then creates its temp file in
  # that hop's directory -- the read-only store -- so it fails with EACCES. A plain
  # open-and-write survives the chain, which is why hand edits reached the repo for
  # months while /auto-mode-setup could not write at all.
  #
  # Linking the two by hand collapses the chain to one hop, into the repo, where a
  # temp file can be created. Ordered after linkGeneration because that is where
  # home-manager deletes the previous generation's links -- including the store hops
  # this replaces -- so the relink has to come afterwards.
  home.activation.linkClaudeWritableConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    for f in settings.json CLAUDE.md; do
      src="${dotfilesClaudePath}/$f"
      dst="$HOME/.claude/$f"
      # No checkout here (fresh machine): leave the path alone rather than dangle a link.
      [ -e "$src" ] || continue
      run mkdir -p "$HOME/.claude"

      # $dst already resolves to $src -- either the link is right already, or
      # ~/.claude itself points into the repo. Every mutation below would then
      # act on the tracked file: `cp a a` exits 1 (and activation runs under
      # `set -e`, so that would kill every later entry), `mv` would rename the
      # repo file away, and `ln` would aim it at itself. Nothing to do.
      if [ -e "$dst" ] && [ "$dst" -ef "$src" ]; then
        continue
      fi

      # A rename() onto the link itself replaces the link with a regular file.
      # Do NOT copy that file back over the repo: a restored or rsynced
      # ~/.claude dereferences symlinks (`cp -r`, `rsync -L` and cloud sync all
      # do), and an interrupted write leaves a truncated file -- either would
      # silently overwrite hand-maintained config. Keep it next to the link and
      # let a human reconcile it instead.
      if [ -f "$dst" ] && [ ! -L "$dst" ]; then
        orphan="$dst.hm-orphan.$(date +%s)"
        if run mv -- "$dst" "$orphan"; then
          warnEcho "$dst was a regular file; kept it as $orphan -- reconcile it with $src by hand"
        else
          warnEcho "could not move $dst aside; leaving it as it is"
          continue
        fi
      fi

      # -T, so a real directory at $dst is an error rather than a link created
      # silently *inside* it. ln then exits 1 there, which `set -e` would turn
      # into an aborted switch, so the failure is reported and skipped.
      run ln -sfnT -- "$src" "$dst" \
        || warnEcho "could not link $dst -> $src (is $dst a directory?)"
    done
  '';

  # Install the plugins settings.json enables (setup-marketplace.sh derives the list
  # from enabledPlugins and is idempotent, so this is a no-op once installed).
  #
  # `claude` is passed by absolute store path: the new generation's bin/ is not on
  # PATH during activation, which is exactly what made the old `command -v claude`
  # guard silently false and left this hook dead. git is prepended for the same
  # reason -- activation's PATH carries coreutils, jq and friends but no git, and a
  # fresh machine needs it to clone the official marketplace.
  #
  # Ordered after linkClaudeWritableConfig rather than merely after writeBoundary:
  # between linkGeneration deleting the old link and that entry recreating it there
  # is a window in which ~/.claude/settings.json does not exist, and `claude` must
  # not be invoked then -- a default file written into the gap would be parked as an
  # .hm-orphan.* file by the guard above and leave ~/.claude unlinked.
  #
  # The marketplace path and the settings file are passed in as absolute paths
  # rather than derived from the script's own location: `claude plugin marketplace
  # add` records whatever path it is handed into Claude Code's state, and a script
  # run out of a throwaway jj workspace would bake in a path that disappears.
  #
  # The per-call `timeout` inside the script bounds one CLI call, not the run, so
  # the whole script gets a single outer deadline as well.
  home.activation.setupClaudeCode = lib.hm.dag.entryAfter [ "linkClaudeWritableConfig" ] ''
    if [ -x "${dotfilesClaudePath}/setup-marketplace.sh" ]; then
      CLAUDE_BIN=${pkgs.claude-code}/bin/claude \
      CLAUDE_MARKETPLACE_PATH="${dotfilesClaudePath}/marketplaces/local" \
      CLAUDE_SETTINGS_FILE="${dotfilesClaudePath}/settings.json" \
      PATH="${lib.makeBinPath [ pkgs.git ]}:$PATH" \
        ${pkgs.coreutils}/bin/timeout -k 30 600 \
          "${dotfilesClaudePath}/setup-marketplace.sh" >/dev/null \
        || warnEcho "setup-marketplace.sh failed or timed out; plugins may be out of date"
    fi
  '';

  # Register crumb's stdio MCP server with Claude Code at user scope. MCP servers
  # live in the stateful ~/.claude.json, so we delegate the file location/format to
  # the `claude` CLI rather than managing it declaratively.
  #
  # `claude` is invoked by absolute store path because the new generation's bin/ is
  # not on PATH during activation; `crumb` is registered as a *bare* command
  # (resolved from PATH when Claude launches it), which keeps the entry stable
  # across crumb updates. crumb has no telemetry, so no env is baked in.
  #
  # The guard adds `crumb` only when it is not already registered, so activation
  # stays idempotent.
  #
  # It is ordered after linkClaudeWritableConfig for the same reason as setupClaudeCode.
  home.activation.registerCrumbMcp = lib.hm.dag.entryAfter [ "linkClaudeWritableConfig" ] ''
    if ! ${pkgs.claude-code}/bin/claude mcp get crumb >/dev/null 2>&1; then
      ${pkgs.claude-code}/bin/claude mcp add crumb -s user -- crumb mcp >/dev/null 2>&1 || true
    fi
  '';
}
