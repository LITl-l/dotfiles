#!/usr/bin/env bash

# Neovim configuration installation script

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Setting up Neovim configuration..."

# Create XDG nvim directory
mkdir -p "$HOME/.config/nvim"

# Link nvim configuration
ln -sf "$SCRIPT_DIR/init.lua" "$HOME/.config/nvim/init.lua"
ln -sf "$SCRIPT_DIR/lua" "$HOME/.config/nvim/lua"

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

# Install mini.nvim. The Nix setup provides it under site/pack/hm; this is the
# standalone equivalent, and it lives here rather than in init.lua so the clone
# only ever happens when a human runs this script -- a clone-on-startup
# fallback once installed a second copy beside the Nix one and silently
# shadowed it.
MINI_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/site/pack/deps/start/mini.nvim"
if [ ! -d "$MINI_DIR" ]; then
    echo "Installing mini.nvim..."
    git clone --filter=blob:none https://github.com/echasnovski/mini.nvim "$MINI_DIR"
    nvim --headless +'helptags ALL' +qa
fi

echo "Neovim setup complete!"
echo "Run 'nvim' to start."
