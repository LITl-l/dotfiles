#!/usr/bin/env bash

# Eza installation script

set -euo pipefail

echo "Setting up Eza..."

# Install eza if not present
if ! command -v eza >/dev/null 2>&1; then
    echo "Installing Eza..."
    if command -v brew >/dev/null 2>&1; then
        brew install eza
    elif command -v cargo >/dev/null 2>&1; then
        cargo install eza
    else
        echo "Please install Homebrew or Rust first to install eza"
        exit 1
    fi
else
    echo "Eza already installed"
fi

echo "Eza setup complete!"