#!/usr/bin/env bash

# Build tools installation script
# This script installs build essentials required for compiling Rust packages

set -euo pipefail

echo "Installing build tools..."

# Check if already installed
if command -v cc >/dev/null 2>&1; then
    echo "Build tools already installed!"
    echo "C compiler: $(which cc)"
    exit 0
fi

# Install based on detected package manager
if command -v apt-get >/dev/null 2>&1; then
    echo "Detected Debian/Ubuntu system. Installing build-essential..."
    sudo apt-get update && sudo apt-get install -y build-essential
elif command -v yum >/dev/null 2>&1; then
    echo "Detected CentOS/RHEL system. Installing Development Tools..."
    sudo yum groupinstall -y "Development Tools"
elif command -v pacman >/dev/null 2>&1; then
    echo "Detected Arch system. Installing base-devel..."
    sudo pacman -S --noconfirm base-devel
elif command -v brew >/dev/null 2>&1; then
    echo "Detected macOS with Homebrew. Installing Xcode command line tools..."
    xcode-select --install 2>/dev/null || echo "Xcode tools may already be installed"
else
    echo "Error: Unable to detect package manager for build tools installation."
    echo "Please install build essentials manually for your distribution."
    exit 1
fi

# Verify installation
if command -v cc >/dev/null 2>&1; then
    echo "Build tools installed successfully!"
    echo "C compiler: $(which cc)"
else
    echo "Error: Build tools installation failed. C compiler still not found."
    exit 1
fi