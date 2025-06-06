#!/usr/bin/env bash

# Sheldon configuration installation script

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Setting up Sheldon configuration..."

# Create XDG sheldon directory
mkdir -p "$HOME/.config/sheldon"

# Link sheldon configuration
ln -sf "$SCRIPT_DIR/plugins.toml" "$HOME/.config/sheldon/plugins.toml"

# Install sheldon if not present
if ! command -v sheldon >/dev/null 2>&1; then
    echo "Installing Sheldon..."
    if command -v cargo >/dev/null 2>&1; then
        cargo install sheldon
    else
        echo "Please install Rust first to install Sheldon"
        echo "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
        exit 1
    fi
fi

echo "Sheldon setup complete!"
echo "Run 'sheldon lock' to update plugins"