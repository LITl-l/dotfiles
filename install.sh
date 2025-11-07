#!/usr/bin/env bash

# NixOS-based Dotfiles Installation Script
# This script installs Nix and Home Manager, then activates the dotfiles configuration

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Detect OS
detect_os() {
    if [ -f /proc/version ] && grep -qi microsoft /proc/version; then
        echo "wsl"
    elif [ "$(uname)" = "Darwin" ]; then
        echo "darwin"
    elif [ "$(uname)" = "Linux" ]; then
        echo "linux"
    else
        echo "unknown"
    fi
}

# Detect system architecture
detect_arch() {
    local arch=$(uname -m)
    case "$arch" in
        x86_64)
            echo "x86_64"
            ;;
        aarch64|arm64)
            echo "aarch64"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Check if Nix is installed
check_nix() {
    if command -v nix >/dev/null 2>&1; then
        log_success "Nix is already installed"
        nix --version
        return 0
    else
        log_warning "Nix is not installed"
        return 1
    fi
}

# Install Nix
install_nix() {
    log_info "Installing Nix..."

    if check_nix; then
        return 0
    fi

    # Install Nix with the Determinate Nix Installer (recommended)
    if command -v curl >/dev/null 2>&1; then
        log_info "Using Determinate Nix Installer for better experience..."
        curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --no-confirm
    else
        log_error "curl is required but not installed. Please install curl first."
        exit 1
    fi

    # Source Nix
    if [ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
        . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
    elif [ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
        . "$HOME/.nix-profile/etc/profile.d/nix.sh"
    fi

    # Verify installation
    if check_nix; then
        log_success "Nix installed successfully!"
    else
        log_error "Nix installation failed"
        exit 1
    fi
}

# Configure Nix
configure_nix() {
    log_info "Configuring Nix..."

    # Ensure Nix config directory exists
    mkdir -p ~/.config/nix

    # Enable flakes and nix-command if not already enabled
    if [ ! -f ~/.config/nix/nix.conf ] || ! grep -q "experimental-features" ~/.config/nix/nix.conf; then
        log_info "Enabling Nix flakes and nix-command..."
        cat > ~/.config/nix/nix.conf <<EOF
experimental-features = nix-command flakes
warn-dirty = false
accept-flake-config = true
EOF
        log_success "Nix configuration updated"
    else
        log_info "Nix flakes already enabled"
    fi
}

# Install Home Manager
install_home_manager() {
    log_info "Home Manager will be installed via the flake..."
    log_success "Home Manager setup complete"
}

# Build and activate Home Manager configuration
activate_configuration() {
    local os_type=$(detect_os)
    local arch=$(detect_arch)
    local username=$(whoami)
    local config=""

    # Determine which configuration to use
    case "$os_type" in
        wsl)
            # Use username-specific config if available (nixos@wsl or user@wsl)
            if [ "$username" = "nixos" ]; then
                config="nixos@wsl"
                log_info "Detected WSL2 environment (NixOS user)"
            else
                config="user@wsl"
                log_info "Detected WSL2 environment"
            fi
            ;;
        darwin)
            config="user@darwin"
            log_info "Detected macOS environment"
            ;;
        linux)
            config="user@linux"
            log_info "Detected Linux environment"
            ;;
        *)
            log_error "Unsupported operating system"
            exit 1
            ;;
    esac

    log_info "Building Home Manager configuration: $config"
    log_info "This may take a while on first run..."

    cd "$SCRIPT_DIR"

    # Build the configuration
    log_info "Building configuration..."
    if ! nix build ".#homeConfigurations.\"$config\".activationPackage" --print-build-logs; then
        log_error "Failed to build Home Manager configuration"
        log_info "You can try manually with: nix build \".#homeConfigurations.\\\"$config\\\".activationPackage\""
        exit 1
    fi

    # Activate the configuration
    log_info "Activating configuration..."
    if ! ./result/activate; then
        log_error "Failed to activate Home Manager configuration"
        exit 1
    fi

    log_success "Configuration activated successfully!"
}

# Update flake inputs
update_flake() {
    log_info "Updating flake inputs..."
    cd "$SCRIPT_DIR"
    nix flake update
    log_success "Flake inputs updated"
}

# Switch to updated configuration
rebuild_configuration() {
    local os_type=$(detect_os)
    local username=$(whoami)
    local config=""

    case "$os_type" in
        wsl)
            if [ "$username" = "nixos" ]; then
                config="nixos@wsl"
            else
                config="user@wsl"
            fi
            ;;
        darwin) config="user@darwin" ;;
        linux) config="user@linux" ;;
    esac

    log_info "Rebuilding configuration: $config"
    cd "$SCRIPT_DIR"

    nix build ".#homeConfigurations.\"$config\".activationPackage" --print-build-logs
    ./result/activate

    log_success "Configuration rebuilt and activated!"
}

# Setup Fish as default shell
setup_fish_shell() {
    log_info "Setting up Fish shell..."

    local fish_path=$(command -v fish 2>/dev/null || echo "")

    if [ -z "$fish_path" ]; then
        log_warning "Fish shell not found in PATH yet. It will be available after reloading your shell."
        return 0
    fi

    # Check if fish is already the default shell
    if [ "$SHELL" = "$fish_path" ]; then
        log_success "Fish is already your default shell"
        return 0
    fi

    # Add fish to /etc/shells if not present
    if ! grep -q "^$fish_path$" /etc/shells 2>/dev/null; then
        log_info "Adding Fish to /etc/shells (requires sudo)..."
        if command -v sudo >/dev/null 2>&1; then
            echo "$fish_path" | sudo tee -a /etc/shells >/dev/null
        else
            log_warning "sudo not available. Please manually add $fish_path to /etc/shells"
            return 0
        fi
    fi

    # Change default shell
    log_info "Changing default shell to Fish (requires password)..."
    if ! chsh -s "$fish_path"; then
        log_warning "Failed to change default shell. You can do this manually with: chsh -s $fish_path"
    else
        log_success "Default shell changed to Fish"
        log_warning "Please log out and back in for the shell change to take effect"
    fi
}

# Show post-installation instructions
show_post_install() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_success "Installation complete!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📝 Next steps:"
    echo ""
    echo "1. Reload your shell to use the new configuration:"
    echo "   ${GREEN}exec \$SHELL${NC}"
    echo ""
    echo "2. (Optional) Configure your Git identity:"
    echo "   Create ~/.config/git/config.local with:"
    echo "   ${BLUE}[user]${NC}"
    echo "   ${BLUE}    name = Your Name${NC}"
    echo "   ${BLUE}    email = your.email@example.com${NC}"
    echo ""
    echo "3. Update your configuration anytime with:"
    echo "   ${GREEN}cd ~/dotfiles && nix flake update && rebuild${NC}"
    echo ""
    echo "4. Or use the convenience alias:"
    echo "   ${GREEN}nix-rebuild${NC}"
    echo ""
    echo "🔧 Installed tools:"
    echo "  - Fish shell with vi mode"
    echo "  - Starship prompt"
    echo "  - Neovim with mini.nvim"
    echo "  - Tmux with plugins"
    echo "  - WezTerm (Linux/macOS)"
    echo "  - Git with delta"
    echo "  - Lazygit"
    echo "  - Modern CLI tools (eza, fd, ripgrep, bat, fzf, etc.)"
    echo ""
    echo "📚 For more information, see the README.md file"
    echo ""
}

# Show usage
show_usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

NixOS-based dotfiles installer

Options:
    -h, --help          Show this help message
    -u, --update        Update flake inputs and rebuild
    -r, --rebuild       Rebuild configuration without updating
    --no-shell-change   Skip changing default shell to Fish

Examples:
    $0                  # Full installation
    $0 --update         # Update and rebuild configuration
    $0 --rebuild        # Rebuild without updating

After installation, use these commands:
    nix-rebuild        # Rebuild configuration
    nix-update         # Update flake inputs
    nix-clean          # Clean old generations

EOF
}

# Main installation function
main() {
    local update_only=false
    local rebuild_only=false
    local change_shell=true

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -u|--update)
                update_only=true
                shift
                ;;
            -r|--rebuild)
                rebuild_only=true
                shift
                ;;
            --no-shell-change)
                change_shell=false
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    # Handle update/rebuild modes
    if [ "$update_only" = true ]; then
        update_flake
        rebuild_configuration
        log_success "Update complete!"
        exit 0
    fi

    if [ "$rebuild_only" = true ]; then
        rebuild_configuration
        log_success "Rebuild complete!"
        exit 0
    fi

    # Full installation
    log_info "Starting NixOS-based dotfiles installation..."
    echo ""

    # Check prerequisites
    if ! command -v curl >/dev/null 2>&1; then
        log_error "curl is required but not installed"
        exit 1
    fi

    if ! command -v git >/dev/null 2>&1; then
        log_error "git is required but not installed"
        exit 1
    fi

    # Install and configure Nix
    install_nix
    configure_nix

    # Source Nix environment
    if [ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
        . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
    elif [ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
        . "$HOME/.nix-profile/etc/profile.d/nix.sh"
    fi

    # Install Home Manager (via flake)
    install_home_manager

    # Build and activate configuration
    activate_configuration

    # Setup Fish shell
    if [ "$change_shell" = true ]; then
        setup_fish_shell
    fi

    # Show post-installation instructions
    show_post_install
}

# Run main function
main "$@"
