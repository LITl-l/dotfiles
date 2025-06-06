#!/usr/bin/env bash

# Homebrew installation script

set -euo pipefail

echo "Setting up Homebrew..."

# Install Homebrew if not present
if ! command -v brew >/dev/null 2>&1; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Add Homebrew to PATH
    echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> "$HOME/.profile"
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
else
    echo "Homebrew already installed"
fi

# Install essential packages
echo "Installing essential packages..."
brew install \
    git \
    curl \
    wget \
    ripgrep \
    fd \
    fzf \
    bat \
    jq \
    yq \
    eza \
    zoxide \
    git-delta

echo "Homebrew setup complete!"