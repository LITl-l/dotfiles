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

  # Register local plugin (symlink marketplace and install via CLI)
  home.activation.registerClaudePlugins = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    MARKETPLACE_DIR="$HOME/.claude/plugins/marketplaces/local"
    LOCAL_MARKETPLACE_SOURCE="${localMarketplacePath}"

    # Create directories
    mkdir -p "$HOME/.claude/plugins/marketplaces"

    # Symlink local marketplace (remove old symlink/dir if exists)
    rm -rf "$MARKETPLACE_DIR"
    ln -sf "$LOCAL_MARKETPLACE_SOURCE" "$MARKETPLACE_DIR"

    # Install plugin via CLI if claude is available
    # This properly registers skills and agents
    if command -v claude &> /dev/null; then
      # Uninstall first to ensure clean state (ignore errors if not installed)
      claude plugin uninstall jj-master@local --scope user 2>/dev/null || true
      # Install the plugin from local marketplace
      claude plugin install jj-master@local --scope user 2>/dev/null || true
    fi
  '';
}

