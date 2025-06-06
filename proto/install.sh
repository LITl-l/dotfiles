#!/usr/bin/env bash

# Proto toolchain manager installation script

set -euo pipefail

echo "Setting up Proto..."

# Check for build essentials (required for Rust compilation)
if ! command -v cc >/dev/null 2>&1; then
    echo "Warning: C compiler not found. Build tools are required for Rust packages."
    echo "Please install build essentials first:"
    echo "  Ubuntu/Debian: sudo apt-get install build-essential"
    echo "  CentOS/RHEL: sudo yum groupinstall 'Development Tools'"
    echo "  Arch: sudo pacman -S base-devel"
    echo ""
    echo "Continuing with proto installation..."
fi

# Install proto if not present
if ! command -v proto >/dev/null 2>&1; then
    echo "Installing Proto..."
    curl -fsSL https://moonrepo.dev/install/proto.sh | bash -s -- --yes
    
    # Source proto environment
    if [ -f "$HOME/.proto/env" ]; then
        source "$HOME/.proto/env"
    fi
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