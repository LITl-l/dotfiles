#!/usr/bin/env bash

# Lazygit installation script

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Setting up Lazygit..."

# Create XDG lazygit directory
mkdir -p "$HOME/.config/lazygit"

# Link lazygit configuration
ln -sf "$SCRIPT_DIR/config.yml" "$HOME/.config/lazygit/config.yml"

# Install lazygit if not present
if ! command -v lazygit >/dev/null 2>&1; then
    echo "Installing Lazygit..."
    
    if command -v brew >/dev/null 2>&1; then
        # Install via Homebrew (preferred method)
        brew install lazygit
    elif command -v go >/dev/null 2>&1; then
        # Install via Go
        go install github.com/jesseduffield/lazygit@latest
    else
        # Install via GitHub releases
        LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        
        if [ -z "$LAZYGIT_VERSION" ]; then
            echo "Failed to get Lazygit version. Please install manually."
            echo "Visit: https://github.com/jesseduffield/lazygit#installation"
            exit 1
        fi
        
        # Determine architecture
        ARCH=$(uname -m)
        case $ARCH in
            x86_64) ARCH="x86_64" ;;
            aarch64|arm64) ARCH="arm64" ;;
            *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
        esac
        
        # Download and install
        curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION#v}_Linux_${ARCH}.tar.gz"
        tar xf lazygit.tar.gz lazygit
        mkdir -p "$HOME/.local/bin"
        install lazygit "$HOME/.local/bin"
        rm lazygit.tar.gz lazygit
        
        echo "Lazygit installed to ~/.local/bin/lazygit"
        echo "Make sure ~/.local/bin is in your PATH"
    fi
else
    echo "Lazygit already installed"
fi

echo "Lazygit setup complete!"
echo "Run 'lazygit' to start using it with the custom configuration"