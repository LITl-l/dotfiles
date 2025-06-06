#!/usr/bin/env bash

# Proto toolchain manager installation script

set -euo pipefail

echo "Setting up Proto..."

# Install proto if not present
if ! command -v proto >/dev/null 2>&1; then
    echo "Installing Proto..."
    curl -fsSL https://moonrepo.dev/install/proto.sh | bash -s -- --yes
else
    echo "Proto already installed"
fi

echo "Proto setup complete!"
echo "Run 'proto install node' to install Node.js"
echo "Run 'proto install python' to install Python"
echo "Run 'proto install rust' to install Rust"