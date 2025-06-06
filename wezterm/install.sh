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
    
    # Try different installation methods based on available package managers
    # Prefer Homebrew (works on both macOS and Linux)
    if command -v brew >/dev/null 2>&1; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            echo "Installing WezTerm via Homebrew (macOS)..."
            brew install --cask wezterm
        else
            echo "Installing WezTerm via Homebrew (Linux)..."
            brew tap wezterm/wezterm-linuxbrew
            brew install wezterm
        fi
        
    # Fallback to flatpak (no sudo required)
    elif command -v flatpak >/dev/null 2>&1; then
        echo "Installing WezTerm via Flatpak (no sudo required)..."
        flatpak install -y flathub org.wezfurlong.wezterm
        
    elif command -v apt-get >/dev/null 2>&1; then
        echo "Installing WezTerm via APT (official repository)..."
        echo "This requires sudo access. You can also install manually:"
        echo "  curl -fsSL https://apt.fury.io/wez/gpg.key | sudo gpg --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg"
        echo "  echo 'deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *' | sudo tee /etc/apt/sources.list.d/wezterm.list"
        echo "  sudo apt update && sudo apt install -y wezterm"
        echo ""
        
        # Check if sudo is available
        if sudo -n true 2>/dev/null; then
            # Add WezTerm official repository
            curl -fsSL https://apt.fury.io/wez/gpg.key | sudo gpg --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg
            echo 'deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *' | sudo tee /etc/apt/sources.list.d/wezterm.list
            
            # Update and install
            sudo apt update
            sudo apt install -y wezterm
        else
            echo "Falling back to AppImage installation (no sudo required)..."
            install_appimage=true
        fi
        
    elif command -v dnf >/dev/null 2>&1; then
        echo "Installing WezTerm via DNF (COPR repository)..."
        if sudo -n true 2>/dev/null; then
            sudo dnf copr enable -y wezfurlong/wezterm-nightly
            sudo dnf install -y wezterm
        else
            echo "sudo access required. Please run manually:"
            echo "  sudo dnf copr enable -y wezfurlong/wezterm-nightly"
            echo "  sudo dnf install -y wezterm"
            echo "Falling back to AppImage installation..."
            install_appimage=true
        fi
        
    elif command -v pacman >/dev/null 2>&1; then
        echo "Installing WezTerm via pacman..."
        if sudo -n true 2>/dev/null; then
            sudo pacman -S --noconfirm wezterm
        else
            echo "sudo access required. Please run manually:"
            echo "  sudo pacman -S wezterm"
            echo "Falling back to AppImage installation..."
            install_appimage=true
        fi
        
    else
        # Fallback to AppImage
        echo "No supported package manager found. Installing WezTerm AppImage..."
        install_appimage=true
    fi
    
    # Install AppImage if needed (fallback method)
    if [ "${install_appimage:-false}" = true ]; then
        echo "Installing WezTerm AppImage..."
        
        # Get the latest release URL
        download_url=$(curl -s https://api.github.com/repos/wez/wezterm/releases/latest | \
            grep "browser_download_url.*Ubuntu.*AppImage" | \
            cut -d '"' -f 4 | \
            head -1)
        
        if [ -z "$download_url" ]; then
            echo "Failed to get WezTerm download URL"
            echo "Please install WezTerm manually from https://wezterm.org/install/linux.html"
            exit 1
        fi
        
        # Download and install AppImage
        mkdir -p "$HOME/.local/bin"
        curl -L -o "$HOME/.local/bin/wezterm" "$download_url"
        chmod +x "$HOME/.local/bin/wezterm"
        
        echo "WezTerm AppImage installed to ~/.local/bin/wezterm"
        echo "Make sure ~/.local/bin is in your PATH"
    fi
else
    echo "WezTerm already installed"
fi

echo "WezTerm setup complete!"