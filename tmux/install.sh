#!/usr/bin/env bash

# Tmux configuration installation script

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Setting up Tmux configuration..."

# Create XDG tmux directory
mkdir -p "$HOME/.config/tmux"
mkdir -p "$HOME/.local/share/tmux/plugins"

# Link tmux configuration
ln -sf "$SCRIPT_DIR/tmux.conf" "$HOME/.config/tmux/tmux.conf"

# Install tmux if not present
if ! command -v tmux >/dev/null 2>&1; then
    echo "Installing Tmux..."
    if command -v brew >/dev/null 2>&1; then
        brew install tmux
    elif command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update && sudo apt-get install -y tmux
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y tmux
    else
        echo "Please install tmux manually"
        exit 1
    fi
fi

# Install TPM (Tmux Plugin Manager)
if [ ! -d "$HOME/.local/share/tmux/plugins/tpm" ]; then
    echo "Installing TPM (Tmux Plugin Manager)..."
    git clone https://github.com/tmux-plugins/tpm "$HOME/.local/share/tmux/plugins/tpm"
fi

echo "Tmux setup complete!"
echo "Start tmux and press prefix + I to install plugins"