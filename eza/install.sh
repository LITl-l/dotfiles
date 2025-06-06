#!/usr/bin/env bash

# Eza installation script

set -euo pipefail

echo "Setting up Eza..."

# Install eza if not present
if ! command -v eza >/dev/null 2>&1; then
    echo "Installing Eza..."
    if command -v brew >/dev/null 2>&1; then
        brew install eza
    else
        # Try to install via cargo (direct command or proto)
        if command -v cargo >/dev/null 2>&1; then
            cargo install eza
        elif command -v proto >/dev/null 2>&1 && proto run cargo -- --version >/dev/null 2>&1; then
            proto run cargo -- install eza
        else
            # Try to source environments as fallback
            if [ -f "$HOME/.cargo/env" ]; then
                source "$HOME/.cargo/env"
            fi
            
            if command -v cargo >/dev/null 2>&1; then
                cargo install eza
            else
                echo "Error: Neither Homebrew nor Rust/Cargo found"
                echo "Please install one of the following:"
                echo "  Option 1 (recommended): ./homebrew/install.sh"
                echo "  Option 2: ./install-build-tools.sh && ./proto/install.sh"
                exit 1
            fi
        fi
    fi
else
    echo "Eza already installed"
fi

echo "Eza setup complete!"