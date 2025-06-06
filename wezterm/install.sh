#!/usr/bin/env bash

# WezTerm configuration installation script

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Setting up WezTerm configuration..."

# Create XDG wezterm directory
mkdir -p "$HOME/.config/wezterm"

# Link wezterm configuration
ln -sf "$SCRIPT_DIR/wezterm.lua" "$HOME/.config/wezterm/wezterm.lua"

# Install wezterm if not present
if ! command -v wezterm >/dev/null 2>&1; then
    echo "Installing WezTerm..."
    
    # Get the latest release URL
    local download_url=$(curl -s https://api.github.com/repos/wez/wezterm/releases/latest | \
        grep "browser_download_url.*Linux.*AppImage" | \
        cut -d '"' -f 4 | \
        grep -v ".zsync" | head -1)
    
    if [ -z "$download_url" ]; then
        echo "Failed to get WezTerm download URL"
        echo "Please install WezTerm manually from https://wezfurlong.org/wezterm/installation.html"
        exit 1
    fi
    
    # Download and install
    mkdir -p "$HOME/.local/bin"
    wget -O "$HOME/.local/bin/wezterm" "$download_url"
    chmod +x "$HOME/.local/bin/wezterm"
    
    echo "WezTerm installed to ~/.local/bin/wezterm"
    echo "Make sure ~/.local/bin is in your PATH"
fi

echo "WezTerm setup complete!"