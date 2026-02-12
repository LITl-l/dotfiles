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

# Plugins to install (add new plugins here)
PLUGINS=(
  "jj-master@local"
)

# Check prerequisites
check_claude() {
  if ! command -v claude &>/dev/null; then
    error "claude CLI not found. Install Claude Code first."
    exit 1
  fi
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

  echo ""
  info "Done! Restart Claude Code to use the new plugins."
}

# Remove marketplace and plugins
uninstall() {
  check_claude

  for plugin in "${PLUGINS[@]}"; do
    info "Removing plugin: $plugin"
    claude plugin uninstall "$plugin" --scope user 2>/dev/null || true
  done

  info "Removing local marketplace..."
  claude plugin marketplace remove local 2>/dev/null || true

  echo ""
  info "Done! Marketplace and plugins removed."
}

# Update marketplace and reinstall plugins
update() {
  check_claude

  info "Updating local marketplace..."
  claude plugin marketplace update local

  for plugin in "${PLUGINS[@]}"; do
    info "Reinstalling plugin: $plugin"
    claude plugin uninstall "$plugin" --scope user 2>/dev/null || true
    claude plugin install "$plugin" --scope user
  done

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
