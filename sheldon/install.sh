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
    
    # Try Homebrew first (preferred - no compilation needed)
    if command -v brew >/dev/null 2>&1; then
        brew install sheldon
    # Fallback to cargo/proto (requires build tools)
    elif command -v cargo >/dev/null 2>&1; then
        cargo install sheldon
    elif command -v proto >/dev/null 2>&1 && proto run cargo -- --version >/dev/null 2>&1; then
        proto run cargo -- install sheldon
    else
        # Try to source environments as fallback
        if [ -f "$HOME/.cargo/env" ]; then
            source "$HOME/.cargo/env"
        fi
        
        if command -v cargo >/dev/null 2>&1; then
            cargo install sheldon
        else
            echo "Error: Neither Homebrew nor Rust/Cargo found"
            echo "Please install one of the following:"
            echo "  Option 1 (recommended): ./homebrew/install.sh"
            echo "  Option 2: ./install-build-tools.sh && ./proto/install.sh"
            exit 1
        fi
    fi
else
    echo "Sheldon already installed"
fi

echo "Sheldon setup complete!"
echo "Run 'sheldon lock' to update plugins"