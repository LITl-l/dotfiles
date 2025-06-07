#!/usr/bin/env bash

# Zsh installation and configuration script

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Setting up Zsh configuration..."

# Create XDG directories
mkdir -p "$HOME/.config/zsh"
mkdir -p "$HOME/.local/state/zsh"
mkdir -p "$HOME/.cache/zsh"

# Clean up any conflicting symlinks first
rm -f "$HOME/.config/zsh/zsh" "$HOME/.config/zsh/.zshenv"

# Link zsh configuration files individually
ln -sf "$SCRIPT_DIR/.zshenv" "$HOME/.zshenv"
ln -sf "$SCRIPT_DIR/abbreviations.zsh" "$HOME/.config/zsh/abbreviations.zsh"
ln -sf "$SCRIPT_DIR/env.zsh" "$HOME/.config/zsh/env.zsh"
ln -sf "$SCRIPT_DIR/functions.zsh" "$HOME/.config/zsh/functions.zsh"

# Install zsh if not present
if ! command -v zsh >/dev/null 2>&1; then
    echo "Installing Zsh..."
    if command -v brew >/dev/null 2>&1; then
        brew install zsh
    elif command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update && sudo apt-get install -y zsh
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y zsh
    else
        echo "Please install zsh manually"
        exit 1
    fi
fi

# Set Zsh as default shell
if [ "$SHELL" != "$(command -v zsh)" ]; then
    echo "Setting Zsh as default shell..."
    ZSH_PATH=$(command -v zsh)
    if ! grep -q "$ZSH_PATH" /etc/shells; then
        echo "$ZSH_PATH" | sudo tee -a /etc/shells
    fi
    chsh -s "$ZSH_PATH"
fi

echo "Zsh setup complete!"