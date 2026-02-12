{ config, pkgs, lib, ... }:

let
  claudeConfigPath = "${../.}/claude";
in
{
  # Claude Code settings - symlinked from dotfiles for easy editing
  # Edit ~/dotfiles/claude/settings.json directly to modify
  home.file.".claude/settings.json".source = "${claudeConfigPath}/settings.json";
  home.file.".claude/stop-hook-git-check.sh".source = "${claudeConfigPath}/stop-hook-git-check.sh";

  # Run marketplace setup script after build (registers marketplace + installs plugins via CLI)
  home.activation.setupClaudeMarketplace = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if command -v claude &>/dev/null; then
      "${claudeConfigPath}/setup-marketplace.sh" 2>/dev/null || true
    fi
  '';
}

