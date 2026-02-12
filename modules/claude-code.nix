{ config, pkgs, lib, ... }:

let
  claudeConfigPath = "${../.}/claude";
in
{
  # Claude Code settings - symlinked from dotfiles for easy editing
  # Edit ~/dotfiles/claude/settings.json directly to modify
  home.file.".claude/settings.json".source = "${claudeConfigPath}/settings.json";
  home.file.".claude/stop-hook-git-check.sh".source = "${claudeConfigPath}/stop-hook-git-check.sh";

  # Local marketplace and plugins are managed via CLI:
  #   ./claude/setup-marketplace.sh            # install
  #   ./claude/setup-marketplace.sh --update   # update after plugin changes
  #   ./claude/setup-marketplace.sh --uninstall
}

