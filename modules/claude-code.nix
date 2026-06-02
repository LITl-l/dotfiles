{ config, pkgs, lib, ... }:

let
  dotfilesClaudePath = "/home/nixos/.config/dotfiles/claude";
  mkSymlink = config.lib.file.mkOutOfStoreSymlink;
in
{
  # Symlink Claude Code config files directly to dotfiles repo (mutable)
  home.file.".claude/settings.json".source = mkSymlink "${dotfilesClaudePath}/settings.json";
  home.file.".claude/CLAUDE.md".source = mkSymlink "${dotfilesClaudePath}/CLAUDE.md";
  home.file.".claude/stop-hook-git-check.sh".source = mkSymlink "${dotfilesClaudePath}/stop-hook-git-check.sh";
  home.file.".claude/stop-phrase-guard.sh".source = mkSymlink "${dotfilesClaudePath}/stop-phrase-guard.sh";
  home.file.".claude/wsl-clipboard-image-hook.sh".source = mkSymlink "${dotfilesClaudePath}/wsl-clipboard-image-hook.sh";
  home.file.".claude/ast-grep-nudge-hook.sh".source = mkSymlink "${dotfilesClaudePath}/ast-grep-nudge-hook.sh";

  # Run marketplace plugin setup after build
  home.activation.setupClaudeCode = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if command -v claude &>/dev/null; then
      "${dotfilesClaudePath}/setup-marketplace.sh" --update 2>/dev/null || true
    fi
  '';

  # Register headroom-ai's stdio MCP server with Claude Code at user scope. MCP
  # servers live in the stateful ~/.claude.json, so we delegate the file
  # location/format to the `claude` CLI rather than managing it declaratively.
  #
  # `claude` is invoked by absolute store path because the new generation's bin/
  # is not on PATH during activation; `headroom` is registered as a *bare*
  # command (resolved from PATH when Claude launches it), which keeps the entry
  # stable across headroom updates. Idempotent: `claude mcp get` exits non-zero
  # when absent, so we add at most once; safe to re-run on every switch.
  home.activation.registerHeadroomMcp = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if ! ${pkgs.claude-code}/bin/claude mcp get headroom >/dev/null 2>&1; then
      ${pkgs.claude-code}/bin/claude mcp add headroom -s user -- headroom mcp serve >/dev/null 2>&1 || true
    fi
  '';
}
