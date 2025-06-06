#!/usr/bin/env bash

# Dotfiles Installation Script
# This script installs and configures all tools with XDG compliance

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# XDG Base Directory Specification
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_BIN_HOME="$HOME/.local/bin"

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Create XDG directories
create_xdg_dirs() {
    log_info "Creating XDG Base Directory structure..."
    mkdir -p "$XDG_CONFIG_HOME"
    mkdir -p "$XDG_DATA_HOME"
    mkdir -p "$XDG_STATE_HOME"
    mkdir -p "$XDG_CACHE_HOME"
    mkdir -p "$XDG_BIN_HOME"
    log_success "XDG directories created"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Install Homebrew for Linux
install_homebrew() {
    if command_exists brew; then
        log_info "Homebrew already installed"
        return
    fi
    
    log_info "Installing Homebrew for Linux..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Add Homebrew to PATH
    echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> "$HOME/.profile"
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    
    log_success "Homebrew installed"
}

# Install packages via Homebrew
install_brew_packages() {
    log_info "Installing packages via Homebrew..."
    
    local packages=(
        "zsh"
        "starship"
        "eza"
        "tmux"
        "neovim"
        "ghq"
        "git"
        "curl"
        "wget"
        "ripgrep"
        "fd"
        "fzf"
        "bat"
        "jq"
        "yq"
        "delta"
    )
    
    for package in "${packages[@]}"; do
        if brew list "$package" &>/dev/null; then
            log_info "$package already installed"
        else
            log_info "Installing $package..."
            brew install "$package"
        fi
    done
    
    log_success "Brew packages installed"
}

# Install Rust and cargo packages
install_rust_packages() {
    if ! command_exists cargo; then
        log_info "Installing Rust..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source "$HOME/.cargo/env"
    fi
    
    log_info "Installing Rust packages..."
    
    local packages=(
        "sheldon"
        "zoxide"
    )
    
    for package in "${packages[@]}"; do
        if command_exists "$package"; then
            log_info "$package already installed"
        else
            log_info "Installing $package..."
            cargo install "$package"
        fi
    done
    
    log_success "Rust packages installed"
}

# Install WezTerm
install_wezterm() {
    if command_exists wezterm; then
        log_info "WezTerm already installed"
        return
    fi
    
    log_info "Installing WezTerm..."
    
    # Get the latest release URL
    local download_url=$(curl -s https://api.github.com/repos/wez/wezterm/releases/latest | \
        grep "browser_download_url.*Linux.*AppImage" | \
        cut -d '"' -f 4 | \
        grep -v ".zsync")
    
    if [ -z "$download_url" ]; then
        log_error "Failed to get WezTerm download URL"
        return 1
    fi
    
    # Download and install
    wget -O "$XDG_BIN_HOME/wezterm" "$download_url"
    chmod +x "$XDG_BIN_HOME/wezterm"
    
    log_success "WezTerm installed"
}

# Install Proto
install_proto() {
    if command_exists proto; then
        log_info "Proto already installed"
        return
    fi
    
    log_info "Installing Proto..."
    curl -fsSL https://moonrepo.dev/install/proto.sh | bash -s -- --yes
    
    log_success "Proto installed"
}

# Setup Docker
setup_docker() {
    log_info "Setting up Docker..."
    
    if ! command_exists docker; then
        log_warning "Docker not installed. Please install Docker manually."
        return
    fi
    
    # Create docker group if it doesn't exist
    if ! getent group docker >/dev/null 2>&1; then
        log_info "Creating docker group..."
        sudo groupadd docker
    fi
    
    # Add current user to docker group
    if ! groups "$USER" | grep -q docker; then
        log_info "Adding $USER to docker group..."
        sudo usermod -aG docker "$USER"
        log_warning "You need to log out and back in for docker group changes to take effect"
    fi
    
    log_success "Docker setup complete"
}

# Link configuration files
link_configs() {
    log_info "Linking configuration files..."
    
    # Create symlinks for each config
    local configs=(
        "zsh:$XDG_CONFIG_HOME/zsh"
        "sheldon:$XDG_CONFIG_HOME/sheldon"
        "starship:$XDG_CONFIG_HOME/starship"
        "wezterm:$XDG_CONFIG_HOME/wezterm"
        "nvim:$XDG_CONFIG_HOME/nvim"
        "tmux:$XDG_CONFIG_HOME/tmux"
        "git:$XDG_CONFIG_HOME/git"
        "eza:$XDG_CONFIG_HOME/eza"
    )
    
    for config in "${configs[@]}"; do
        local src="${config%%:*}"
        local dest="${config#*:}"
        
        if [ -e "$dest" ] && [ ! -L "$dest" ]; then
            log_warning "$dest exists and is not a symlink. Backing up..."
            mv "$dest" "$dest.backup.$(date +%Y%m%d%H%M%S)"
        fi
        
        if [ ! -e "$dest" ]; then
            ln -sf "$SCRIPT_DIR/config/$src" "$dest"
            log_success "Linked $src config"
        fi
    done
    
    # Special case for .zshenv in home directory
    if [ ! -e "$HOME/.zshenv" ]; then
        ln -sf "$SCRIPT_DIR/.zshenv" "$HOME/.zshenv"
        log_success "Linked .zshenv to home directory"
    fi
}

# Setup Zsh as default shell
setup_zsh() {
    log_info "Setting up Zsh..."
    
    local zsh_path=$(command -v zsh)
    
    if [ -z "$zsh_path" ]; then
        log_error "Zsh not found"
        return 1
    fi
    
    # Add zsh to /etc/shells if not already there
    if ! grep -q "$zsh_path" /etc/shells; then
        log_info "Adding $zsh_path to /etc/shells..."
        echo "$zsh_path" | sudo tee -a /etc/shells
    fi
    
    # Change default shell if not already zsh
    if [ "$SHELL" != "$zsh_path" ]; then
        log_info "Changing default shell to Zsh..."
        chsh -s "$zsh_path"
        log_success "Default shell changed to Zsh. Please log out and back in."
    else
        log_info "Zsh is already the default shell"
    fi
}

# Install abbreviations via sheldon
setup_abbreviations() {
    log_info "Setting up abbreviations..."
    
    # This will be handled by sheldon plugins
    log_success "Abbreviations will be configured via sheldon"
}

# Main installation function
main() {
    log_info "Starting dotfiles installation..."
    
    # Create XDG directories
    create_xdg_dirs
    
    # Install tools
    install_homebrew
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    install_brew_packages
    install_rust_packages
    install_wezterm
    install_proto
    setup_docker
    
    # Link configuration files
    link_configs
    
    # Setup shell
    setup_zsh
    
    # Setup abbreviations
    setup_abbreviations
    
    log_success "Dotfiles installation complete!"
    log_info "Please restart your terminal or run 'exec zsh' to apply changes"
}

# Run main function
main "$@"