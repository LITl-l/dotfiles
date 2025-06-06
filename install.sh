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

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# XDG Base Directory Specification
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_BIN_HOME="$HOME/.local/bin"

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

# Run individual tool installation scripts
install_tool() {
    local tool="$1"
    local install_script="$SCRIPT_DIR/$tool/install.sh"
    
    if [ -f "$install_script" ]; then
        log_info "Installing $tool..."
        
        # Special handling for homebrew to ensure environment is loaded
        if [ "$tool" = "homebrew" ]; then
            if bash "$install_script"; then
                # Load homebrew environment after installation
                if [ -d "/home/linuxbrew/.linuxbrew" ]; then
                    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
                    export PATH="/home/linuxbrew/.linuxbrew/bin:$PATH"
                fi
                log_success "$tool installation completed"
            else
                log_error "$tool installation failed"
                return 1
            fi
        else
            if bash "$install_script"; then
                log_success "$tool installation completed"
            else
                log_error "$tool installation failed"
                return 1
            fi
        fi
    else
        log_warning "No installation script found for $tool"
    fi
}

# Install all tools
install_all_tools() {
    local tools=(
        "homebrew"
        "proto"
        "zsh"
        "git"
        "lazygit"
        "starship"
        "sheldon"
        "nvim"
        "tmux"
        "wezterm"
        "eza"
        "docker"
    )
    
    for tool in "${tools[@]}"; do
        install_tool "$tool"
        
        # After installing homebrew, ensure it's available for subsequent tools
        if [ "$tool" = "homebrew" ] && command -v brew >/dev/null 2>&1; then
            log_info "Homebrew is now available for subsequent installations"
        fi
        
        # After installing proto, ensure it and rust are available for subsequent tools
        if [ "$tool" = "proto" ]; then
            if command -v proto >/dev/null 2>&1; then
                log_info "Proto toolchain manager is now available for subsequent installations"
                if proto run cargo -- --version >/dev/null 2>&1; then
                    log_info "Rust/Cargo is now available via proto for subsequent installations"
                fi
            fi
        fi
    done
}

# Install specific tools
install_specific_tools() {
    for tool in "$@"; do
        if [ -d "$SCRIPT_DIR/$tool" ]; then
            install_tool "$tool"
        else
            log_error "Tool '$tool' not found"
        fi
    done
}

# List available tools
list_tools() {
    log_info "Available tools:"
    for dir in "$SCRIPT_DIR"/*/; do
        if [ -f "$dir/install.sh" ]; then
            tool=$(basename "$dir")
            echo "  - $tool"
        fi
    done
}

# Show usage information
show_usage() {
    echo "Usage: $0 [OPTIONS] [TOOLS...]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -l, --list     List available tools"
    echo "  -a, --all      Install all tools (default)"
    echo ""
    echo "Examples:"
    echo "  $0                    # Install all tools"
    echo "  $0 --all              # Install all tools"
    echo "  $0 zsh git nvim       # Install specific tools"
    echo "  $0 --list             # List available tools"
    echo ""
    echo "Available tools can be installed individually by running:"
    echo "  ./TOOL_NAME/install.sh"
}

# Main installation function
main() {
    local install_all=true
    local specific_tools=()
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -l|--list)
                list_tools
                exit 0
                ;;
            -a|--all)
                install_all=true
                shift
                ;;
            *)
                install_all=false
                specific_tools+=("$1")
                shift
                ;;
        esac
    done
    
    log_info "Starting dotfiles installation..."
    
    # Check for build tools (required for Rust packages)
    if ! command -v cc >/dev/null 2>&1; then
        log_warning "Build tools not detected. Some tools (sheldon, eza) require compilation."
        log_info "Run './install-build-tools.sh' first if you encounter compilation errors."
        echo ""
    fi
    
    # Create XDG directories
    create_xdg_dirs
    
    # Install tools
    if [ "$install_all" = true ]; then
        install_all_tools
    else
        install_specific_tools "${specific_tools[@]}"
    fi
    
    log_success "Dotfiles installation complete!"
    log_info "Please restart your terminal or run 'exec zsh' to apply changes"
    
    # Additional setup notes
    echo ""
    echo "Additional setup notes:"
    echo "- Create ~/.config/git/config.local with your git user information"
    echo "- Start tmux and press Ctrl+a + I to install tmux plugins"
    echo "- Run 'sheldon lock' to update zsh plugins"
    echo "- If you installed Docker, log out and back in for group changes to take effect"
}

# Run main function with all arguments
main "$@"