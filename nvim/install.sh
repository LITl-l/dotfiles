#!/usr/bin/env bash

# Neovim configuration installation script

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Setting up Neovim configuration..."

# Create XDG nvim directory
mkdir -p "$HOME/.config/nvim"

# Link nvim configuration
ln -sf "$SCRIPT_DIR/init.lua" "$HOME/.config/nvim/init.lua"

# Install neovim if not present
if ! command -v nvim >/dev/null 2>&1; then
    echo "Installing Neovim..."
    if command -v brew >/dev/null 2>&1; then
        brew install neovim
    elif command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update && sudo apt-get install -y neovim
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y neovim
    else
        echo "Please install neovim manually"
        exit 1
    fi
fi

echo "Neovim setup complete!"
echo "Run 'nvim' to start and mini.nvim will auto-install on first run."