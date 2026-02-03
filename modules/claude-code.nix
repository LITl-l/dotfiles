{ config, pkgs, lib, ... }:

let
  # Path to dotfiles repo (adjust if needed)
  dotfilesPath = ../.; # Relative to this module
  localMarketplacePath = "${dotfilesPath}/claude/marketplaces/local";
  claudeConfigPath = "${dotfilesPath}/claude";
in
{
  # Claude Code settings - symlinked from dotfiles for easy editing
  # Edit ~/dotfiles/claude/settings.json directly to modify
  home.file.".claude/settings.json".source = "${claudeConfigPath}/settings.json";
  home.file.".claude/stop-hook-git-check.sh".source = "${claudeConfigPath}/stop-hook-git-check.sh";
  home.file.".claude/merge-plugin-configs.sh" = {
    source = "${claudeConfigPath}/merge-plugin-configs.sh";
    executable = true;
  };

  # Register local plugin using merge strategy (preserves locally-installed plugins)
  home.activation.registerClaudePlugins = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    MARKETPLACE_DIR="$HOME/.claude/plugins/marketplaces/local"
    LOCAL_MARKETPLACE_SOURCE="${localMarketplacePath}"

    # Create directories
    mkdir -p "$HOME/.claude/plugins/marketplaces"

    # Symlink local marketplace (remove old symlink/dir if exists)
    rm -rf "$MARKETPLACE_DIR"
    ln -sf "$LOCAL_MARKETPLACE_SOURCE" "$MARKETPLACE_DIR"

    # Merge plugin configs (preserves existing plugins, adds managed ones)
    # This uses jq to merge rather than overwrite
    if [[ -x "$HOME/.claude/merge-plugin-configs.sh" ]]; then
      PATH="${pkgs.jq}/bin:$PATH" "$HOME/.claude/merge-plugin-configs.sh"
    fi
  '';
}

