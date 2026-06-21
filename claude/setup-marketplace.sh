#!/usr/bin/env bash
# Setup local marketplace and plugins for Claude Code
# Run this script from a separate terminal (not inside Claude Code)
#
# Usage:
#   ./setup-marketplace.sh              # Install marketplace and plugins
#   ./setup-marketplace.sh --uninstall  # Remove marketplace and plugins
#   ./setup-marketplace.sh --update     # Update marketplace and reinstall plugins

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MARKETPLACE_PATH="$SCRIPT_DIR/marketplaces/local"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# Plugins to install from the local marketplace (add new plugins here).
# Keep this in sync with the "@local" entries in claude/settings.json's
# enabledPlugins.
PLUGINS=(
  "jj-master@local"
  "architect@local"
)

# Plugins to install from the official marketplace. settings.json's
# enabledPlugins only TOGGLES these on/off -- it does not fetch them, so any
# official plugin enabled there must also be listed here to actually install.
# Keep this in sync with the enabled "@claude-plugins-official" entries.
OFFICIAL_MARKETPLACE="anthropics/claude-plugins-official"
OFFICIAL_PLUGINS=(
  "sourcegraph@claude-plugins-official"
)

# Remote MCP servers registered at user scope (not bundled as plugins).
# context7: streamable-HTTP remote MCP. Replaces the npx @upstash/context7-mcp
# plugin, whose server targets context7.com (unreachable here -> the hangs). The
# remote host mcp.context7.com responds without spawning a local Node process.
# Optional: export CONTEXT7_API_KEY before running for higher rate limits.
CONTEXT7_MCP_URL="https://mcp.context7.com/mcp"

# Check prerequisites
check_claude() {
  if ! command -v claude &>/dev/null; then
    error "claude CLI not found. Install Claude Code first."
    exit 1
  fi
}

# Register remote MCP servers (idempotent at user scope)
setup_mcp() {
  check_claude

  if claude mcp get context7 &>/dev/null; then
    info "MCP server already registered: context7"
    return 0
  fi

  info "Adding remote MCP server: context7 ($CONTEXT7_MCP_URL)"
  if [[ -n "${CONTEXT7_API_KEY:-}" ]]; then
    claude mcp add --transport http --scope user context7 "$CONTEXT7_MCP_URL" \
      --header "CONTEXT7_API_KEY: ${CONTEXT7_API_KEY}"
  else
    claude mcp add --transport http --scope user context7 "$CONTEXT7_MCP_URL"
  fi
}

# Remove remote MCP servers
remove_mcp() {
  check_claude
  info "Removing remote MCP server: context7"
  claude mcp remove context7 2>/dev/null || true
}

# Install marketplace and plugins
install() {
  check_claude

  if [[ ! -d "$MARKETPLACE_PATH" ]]; then
    error "Marketplace directory not found: $MARKETPLACE_PATH"
    exit 1
  fi

  info "Adding local marketplace from: $MARKETPLACE_PATH"
  claude plugin marketplace add "$MARKETPLACE_PATH"

  for plugin in "${PLUGINS[@]}"; do
    info "Installing plugin: $plugin"
    claude plugin install "$plugin" --scope user
  done

  info "Adding official marketplace: $OFFICIAL_MARKETPLACE"
  claude plugin marketplace add "$OFFICIAL_MARKETPLACE" 2>/dev/null || true

  for plugin in "${OFFICIAL_PLUGINS[@]}"; do
    info "Installing plugin: $plugin"
    claude plugin install "$plugin" --scope user
  done

  setup_mcp

  echo ""
  info "Done! Restart Claude Code to use the new plugins."
}

# Remove marketplace and plugins
uninstall() {
  check_claude

  for plugin in "${PLUGINS[@]}" "${OFFICIAL_PLUGINS[@]}"; do
    info "Removing plugin: $plugin"
    claude plugin uninstall "$plugin" --scope user 2>/dev/null || true
  done

  info "Removing local marketplace..."
  claude plugin marketplace remove local 2>/dev/null || true

  remove_mcp

  echo ""
  info "Done! Marketplace and plugins removed."
}

# Update marketplace and reinstall plugins
update() {
  check_claude

  info "Updating local marketplace..."
  claude plugin marketplace add "$MARKETPLACE_PATH" 2>/dev/null || true
  claude plugin marketplace update local

  for plugin in "${PLUGINS[@]}"; do
    info "Reinstalling plugin: $plugin"
    claude plugin uninstall "$plugin" --scope user 2>/dev/null || true
    claude plugin install "$plugin" --scope user
  done

  info "Updating official marketplace..."
  claude plugin marketplace add "$OFFICIAL_MARKETPLACE" 2>/dev/null || true
  claude plugin marketplace update claude-plugins-official

  for plugin in "${OFFICIAL_PLUGINS[@]}"; do
    info "Reinstalling plugin: $plugin"
    claude plugin uninstall "$plugin" --scope user 2>/dev/null || true
    claude plugin install "$plugin" --scope user
  done

  remove_mcp
  setup_mcp

  echo ""
  info "Done! Restart Claude Code to pick up changes."
}

case "${1:-}" in
  --uninstall)
    uninstall
    ;;
  --update)
    update
    ;;
  --help|-h)
    echo "Usage: $(basename "$0") [--uninstall|--update|--help]"
    echo ""
    echo "  (no args)     Install local marketplace and plugins"
    echo "  --update      Update marketplace and reinstall plugins"
    echo "  --uninstall   Remove marketplace and plugins"
    echo "  --help        Show this help"
    ;;
  *)
    install
    ;;
esac
