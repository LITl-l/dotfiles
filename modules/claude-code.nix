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

  # Run marketplace plugin setup after build
  home.activation.setupClaudeCode = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if command -v claude &>/dev/null; then
      "${dotfilesClaudePath}/setup-marketplace.sh" --update 2>/dev/null || true
    fi
  '';
}
