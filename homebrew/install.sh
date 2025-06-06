#!/usr/bin/env bash

# Homebrew installation script

set -euo pipefail

echo "Setting up Homebrew..."

# Install Homebrew if not present
if ! command -v brew >/dev/null 2>&1; then
    echo "Installing Homebrew..."
    
    # Check for curl
    if ! command -v curl >/dev/null 2>&1; then
        echo "Error: curl is required to install Homebrew"
        echo "Please install curl first: sudo apt-get install curl"
        exit 1
    fi
    
    # Install Homebrew
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
        echo "Error: Failed to install Homebrew"
        echo "Please check your internet connection and try again"
        exit 1
    }
    
    # Add Homebrew to PATH for different shells
    if [ -f "$HOME/.profile" ]; then
        echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> "$HOME/.profile"
    fi
    
    if [ -f "$HOME/.bashrc" ]; then
        echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> "$HOME/.bashrc"
    fi
    
    if [ -f "$HOME/.zshrc" ]; then
        echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> "$HOME/.zshrc"
    fi
    
    # Load Homebrew environment for current session
    if [ -d "/home/linuxbrew/.linuxbrew" ]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    else
        echo "Warning: Homebrew installation directory not found"
        echo "You may need to restart your shell or run:"
        echo "  eval \"\$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)\""
    fi
else
    echo "Homebrew already installed"
    # Ensure brew is in PATH
    if [ -d "/home/linuxbrew/.linuxbrew" ]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    fi
fi

# Verify brew is available
if ! command -v brew >/dev/null 2>&1; then
    echo "Error: brew command not found after installation"
    echo "Please restart your shell and run this script again"
    exit 1
fi

# Update Homebrew
echo "Updating Homebrew..."
brew update || echo "Warning: Failed to update Homebrew"

# Install essential packages
echo "Installing essential packages..."

# List of packages to install
packages=(
    "git"
    "curl"
    "wget"
    "ripgrep"
    "fd"
    "fzf"
    "bat"
    "jq"
    "yq"
    "eza"
    "zoxide"
    "git-delta"
)

# Install packages one by one to handle errors gracefully
for package in "${packages[@]}"; do
    if brew list "$package" &>/dev/null; then
        echo "  ✓ $package already installed"
    else
        echo "  → Installing $package..."
        if brew install "$package"; then
            echo "  ✓ $package installed successfully"
        else
            echo "  ✗ Failed to install $package (continuing...)"
        fi
    fi
done

echo ""
echo "Homebrew setup complete!"
echo ""
echo "Note: If brew command is not found, please run:"
echo "  eval \"\$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)\""
echo "Or restart your shell."