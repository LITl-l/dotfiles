#!/usr/bin/env bash

# Starship configuration installation script

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Setting up Starship configuration..."

# Create XDG starship directory
mkdir -p "$HOME/.config/starship"

# Link starship configuration
ln -sf "$SCRIPT_DIR/starship.toml" "$HOME/.config/starship/starship.toml"

# Install starship if not present
if ! command -v starship >/dev/null 2>&1; then
    echo "Installing Starship..."
    if command -v brew >/dev/null 2>&1; then
        brew install starship
    else
        # Use the official installer (preferred method)
        curl -sS https://starship.rs/install.sh | sh -s -- --yes
    fi
fi

echo "Starship setup complete!"