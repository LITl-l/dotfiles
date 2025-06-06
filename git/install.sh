#!/usr/bin/env bash

# Git configuration installation script

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Setting up Git configuration..."

# Create XDG git directory
mkdir -p "$HOME/.config/git"

# Link git configuration files
ln -sf "$SCRIPT_DIR/config" "$HOME/.config/git/config"
ln -sf "$SCRIPT_DIR/ignore" "$HOME/.config/git/ignore"
ln -sf "$SCRIPT_DIR/attributes" "$HOME/.config/git/attributes"

# Install git if not present
if ! command -v git >/dev/null 2>&1; then
    echo "Installing Git..."
    if command -v brew >/dev/null 2>&1; then
        brew install git
    elif command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update && sudo apt-get install -y git
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y git
    else
        echo "Please install git manually"
        exit 1
    fi
fi

# Install delta for better diffs
if ! command -v delta >/dev/null 2>&1; then
    echo "Installing delta..."
    if command -v brew >/dev/null 2>&1; then
        brew install git-delta
    elif command -v cargo >/dev/null 2>&1; then
        cargo install git-delta
    else
        echo "Please install delta manually or install Rust first"
    fi
fi

# Install ghq for repository management
if ! command -v ghq >/dev/null 2>&1; then
    echo "Installing ghq..."
    if command -v brew >/dev/null 2>&1; then
        brew install ghq
    elif command -v go >/dev/null 2>&1; then
        go install github.com/x-motemen/ghq@latest
    else
        echo "Please install ghq manually or install Go first"
    fi
fi

echo "Git setup complete!"
echo "Don't forget to create ~/.config/git/config.local with your user information:"
echo "[user]"
echo "    name = Your Name"
echo "    email = your.email@example.com"