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

  # Register local plugin (symlink marketplace and register in installed_plugins.json)
  home.activation.registerClaudePlugins = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    PLUGINS_FILE="$HOME/.claude/plugins/installed_plugins.json"
    MARKETPLACES_FILE="$HOME/.claude/plugins/known_marketplaces.json"
    MARKETPLACE_DIR="$HOME/.claude/plugins/marketplaces/local"
    PLUGIN_PATH="$MARKETPLACE_DIR/plugins/jj-master"
    LOCAL_MARKETPLACE_SOURCE="${localMarketplacePath}"

    # Create directories
    mkdir -p "$HOME/.claude/plugins/marketplaces"

    # Symlink local marketplace (remove old symlink/dir if exists)
    rm -rf "$MARKETPLACE_DIR"
    ln -sf "$LOCAL_MARKETPLACE_SOURCE" "$MARKETPLACE_DIR"

    # Create plugins file if not exists
    if [ ! -f "$PLUGINS_FILE" ]; then
      echo '{"version":2,"plugins":{}}' > "$PLUGINS_FILE"
    fi

    # Remove invalid local marketplace entry from known_marketplaces.json if it exists
    if [ -f "$MARKETPLACES_FILE" ]; then
      ${pkgs.jq}/bin/jq 'del(.["local"])' "$MARKETPLACES_FILE" > "$MARKETPLACES_FILE.tmp" && mv "$MARKETPLACES_FILE.tmp" "$MARKETPLACES_FILE"
    fi

    # Add jj-master plugin entry
    ${pkgs.jq}/bin/jq --arg path "$PLUGIN_PATH" '
      .plugins["jj-master@local"] = [{
        "scope": "user",
        "installPath": $path,
        "version": "local",
        "installedAt": (now | strftime("%Y-%m-%dT%H:%M:%S.000Z")),
        "lastUpdated": (now | strftime("%Y-%m-%dT%H:%M:%S.000Z"))
      }]
    ' "$PLUGINS_FILE" > "$PLUGINS_FILE.tmp" && mv "$PLUGINS_FILE.tmp" "$PLUGINS_FILE"
  '';
}

