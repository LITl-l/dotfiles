#!/usr/bin/env bash
# Merge plugin configs to preserve locally-installed plugins during home-manager builds
# This script merges existing configs with dotfiles-managed entries

set -euo pipefail

CLAUDE_PLUGINS_DIR="$HOME/.claude/plugins"
INSTALLED_PLUGINS_FILE="$CLAUDE_PLUGINS_DIR/installed_plugins.json"
KNOWN_MARKETPLACES_FILE="$CLAUDE_PLUGINS_DIR/known_marketplaces.json"

# Dotfiles-managed plugins (format: "plugin@marketplace")
# These will always be registered, but won't remove other plugins
MANAGED_PLUGINS=(
  "jj-master@local"
)

# Dotfiles-managed marketplaces
# These will always be registered, but won't remove other marketplaces
MANAGED_MARKETPLACES=(
  "local"
)

# Ensure directory exists
mkdir -p "$CLAUDE_PLUGINS_DIR"

# Initialize installed_plugins.json if it doesn't exist
if [[ ! -f "$INSTALLED_PLUGINS_FILE" ]]; then
  echo '{"version":2,"plugins":{}}' > "$INSTALLED_PLUGINS_FILE"
fi

# Initialize known_marketplaces.json if it doesn't exist
if [[ ! -f "$KNOWN_MARKETPLACES_FILE" ]]; then
  echo '{}' > "$KNOWN_MARKETPLACES_FILE"
fi

# Function to register a plugin via CLI (merges, doesn't overwrite)
register_plugin() {
  local plugin="$1"
  if command -v claude &> /dev/null; then
    # Check if plugin is already installed
    if jq -e --arg p "$plugin" '.plugins[$p] != null' "$INSTALLED_PLUGINS_FILE" > /dev/null 2>&1; then
      echo "Plugin $plugin already installed, skipping..."
    else
      echo "Installing plugin: $plugin"
      claude plugin install "$plugin" --scope user 2>/dev/null || true
    fi
  else
    echo "Warning: claude CLI not found, cannot install plugin: $plugin"
  fi
}

# Function to ensure marketplace is registered
# Note: Marketplaces from extraKnownMarketplaces in settings.json are auto-discovered
# This function is for marketplaces that need explicit registration in known_marketplaces.json
register_marketplace() {
  local marketplace="$1"
  local marketplace_path="$HOME/.claude/plugins/marketplaces/$marketplace"

  # Only add to known_marketplaces.json if marketplace directory exists
  # and it's not already registered
  if [[ -d "$marketplace_path" ]]; then
    if ! jq -e --arg m "$marketplace" '.[$m] != null' "$KNOWN_MARKETPLACES_FILE" > /dev/null 2>&1; then
      echo "Registering marketplace: $marketplace"
      local timestamp
      timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")

      jq --arg m "$marketplace" \
         --arg path "$marketplace_path" \
         --arg ts "$timestamp" \
         '.[$m] = {
           "source": {
             "source": "directory",
             "path": $path
           },
           "installLocation": $path,
           "lastUpdated": $ts
         }' "$KNOWN_MARKETPLACES_FILE" > "$KNOWN_MARKETPLACES_FILE.tmp" \
         && mv "$KNOWN_MARKETPLACES_FILE.tmp" "$KNOWN_MARKETPLACES_FILE"
    else
      echo "Marketplace $marketplace already registered, skipping..."
    fi
  fi
}

echo "=== Merging Claude plugin configs ==="
echo "Preserving existing plugins and marketplaces..."

# Register managed marketplaces (merge, don't overwrite)
for marketplace in "${MANAGED_MARKETPLACES[@]}"; do
  register_marketplace "$marketplace"
done

# Register managed plugins (merge, don't overwrite)
for plugin in "${MANAGED_PLUGINS[@]}"; do
  register_plugin "$plugin"
done

echo "=== Plugin config merge complete ==="
echo "Installed plugins:"
jq -r '.plugins | keys[]' "$INSTALLED_PLUGINS_FILE" 2>/dev/null || echo "(none)"
echo ""
echo "Known marketplaces:"
jq -r 'keys[]' "$KNOWN_MARKETPLACES_FILE" 2>/dev/null || echo "(none)"
