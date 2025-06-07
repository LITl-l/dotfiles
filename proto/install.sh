#!/usr/bin/env bash

# Proto toolchain manager installation script

set -euo pipefail

echo "Setting up Proto..."

# Check for build essentials (required for Rust compilation)
if ! command -v cc >/dev/null 2>&1; then
    echo "Error: Build tools not found. C compiler is required for Rust package compilation."
    echo ""
    echo "Please install build essentials first:"
    
    if command -v apt-get >/dev/null 2>&1; then
        echo "  sudo apt-get update && sudo apt-get install -y build-essential"
    elif command -v yum >/dev/null 2>&1; then
        echo "  sudo yum groupinstall -y 'Development Tools'"
    elif command -v pacman >/dev/null 2>&1; then
        echo "  sudo pacman -S base-devel"
    else
        echo "  Install build tools for your distribution"
    fi
    
    echo ""
    echo "Alternatively, run the build tools installer:"
    echo "  ./install-build-tools.sh"
    echo ""
    echo "After installing build tools, re-run this script."
    exit 1
fi

# Install proto if not present
if ! command -v proto >/dev/null 2>&1; then
    echo "Installing Proto..."
    curl -fsSL https://moonrepo.dev/install/proto.sh | bash -s -- --yes
    
    # Proto is installed to a specific location
    PROTO_BIN="$HOME/.local/share/proto/bin/proto"
    
    # Check if proto was installed successfully
    if [ ! -f "$PROTO_BIN" ]; then
        echo "Error: Proto installation failed. Expected binary not found at $PROTO_BIN"
        exit 1
    fi
    
    # Add proto to PATH for this session
    export PATH="$HOME/.local/share/proto/bin:$PATH"
    echo "Proto installed successfully"
else
    echo "Proto already installed"
fi

# Install Rust via proto
echo "Installing Rust via Proto..."

if command -v proto >/dev/null 2>&1; then
    proto install rust
    echo "Rust installed via proto"
else
    echo "Error: proto command not found after installation"
    exit 1
fi

# Verify rust is available via proto
if proto run rust -- --version >/dev/null 2>&1; then
    echo "Rust available via proto run"
else
    echo "Warning: Rust may not be properly configured with proto"
fi

echo "Proto setup complete!"
echo "Rust/Cargo available via proto toolchain manager"