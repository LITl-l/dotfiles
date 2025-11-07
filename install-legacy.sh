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

# Global array to track failed installations
FAILED_TOOLS=()

# Run individual tool installation scripts (resilient version)
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
                return 0
            else
                log_error "$tool installation failed - continuing with other tools"
                FAILED_TOOLS+=("$tool")
                return 1
            fi
        else
            if bash "$install_script"; then
                log_success "$tool installation completed"
                return 0
            else
                log_error "$tool installation failed - continuing with other tools"
                FAILED_TOOLS+=("$tool")
                return 1
            fi
        fi
    else
        log_warning "No installation script found for $tool"
        FAILED_TOOLS+=("$tool")
        return 1
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
    )
    
    for tool in "${tools[@]}"; do
        # Continue installation even if individual tools fail
        install_tool "$tool" || true
        
        # After installing homebrew, ensure it's available for subsequent tools
        if [ "$tool" = "homebrew" ] && command -v brew >/dev/null 2>&1; then
            log_info "Homebrew is now available for subsequent installations"
        fi
        
        # After installing proto, ensure it and rust are available for subsequent tools
        if [ "$tool" = "proto" ]; then
            # Add proto to PATH if it was just installed
            if [ -d "$HOME/.local/share/proto/bin" ]; then
                export PATH="$HOME/.local/share/proto/bin:$PATH"
            fi
            
            if command -v proto >/dev/null 2>&1; then
                log_info "Proto toolchain manager is now available for subsequent installations"
                if proto run cargo -- --version >/dev/null 2>&1; then
                    log_info "Rust/Cargo is now available via proto for subsequent installations"
                fi
            fi
        fi
        
        # After installing zsh, check and change default shell
        if [ "$tool" = "zsh" ]; then
            check_and_change_shell
        fi
    done
}

# Install specific tools
install_specific_tools() {
    for tool in "$@"; do
        if [ -d "$SCRIPT_DIR/$tool" ]; then
            # Continue installation even if individual tools fail
            install_tool "$tool" || true
            
            # After installing zsh, check and change default shell
            if [ "$tool" = "zsh" ]; then
                check_and_change_shell
            fi
        else
            log_error "Tool '$tool' not found"
            FAILED_TOOLS+=("$tool")
        fi
    done
}

# Report failed tool installations
report_failed_tools() {
    if [ ${#FAILED_TOOLS[@]} -eq 0 ]; then
        return 0
    fi
    
    echo ""
    log_error "The following tools failed to install:"
    echo ""
    
    for tool in "${FAILED_TOOLS[@]}"; do
        case "$tool" in
            "homebrew")
                echo "❌ $tool - Install manually:"
                echo "   curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh | bash"
                echo ""
                ;;
            "proto")
                echo "❌ $tool - Install manually:"
                echo "   curl -fsSL https://moonrepo.dev/install/proto.sh | bash"
                echo "   Then: proto install rust"
                echo ""
                ;;
            "docker")
                echo "❌ $tool - Install manually:"
                echo "   Run: ./docker/install.sh"
                echo "   Or visit: https://docs.docker.com/engine/install/"
                echo ""
                ;;
            "zsh"|"git"|"lazygit"|"starship"|"sheldon"|"nvim"|"tmux"|"wezterm"|"eza")
                echo "❌ $tool - Re-run installation:"
                echo "   ./$tool/install.sh"
                echo ""
                ;;
            *)
                echo "❌ $tool - Check tool directory or installation script"
                echo ""
                ;;
        esac
    done
    
    echo "After resolving the issues above, you can re-run the installation:"
    echo "  ./install.sh"
    echo ""
    echo "Or install specific tools:"
    echo "  ./install.sh ${FAILED_TOOLS[*]}"
    echo ""
}

# Check and change default shell to zsh
check_and_change_shell() {
    log_info "Checking default shell..."
    
    # Get current shell
    local current_shell=$(basename "$SHELL")
    local zsh_path=""
    
    # Find zsh path
    if command -v zsh >/dev/null 2>&1; then
        zsh_path=$(command -v zsh)
    else
        log_warning "zsh not found. It will be installed during the setup."
        return 0
    fi
    
    # Check if current shell is already zsh
    if [ "$current_shell" = "zsh" ]; then
        log_success "Default shell is already zsh"
        return 0
    fi
    
    log_info "Current default shell is: $current_shell"
    log_info "Changing default shell to zsh..."
    
    # Check if zsh is in /etc/shells
    if ! grep -q "^${zsh_path}$" /etc/shells; then
        log_warning "zsh path not found in /etc/shells. You may need to add it manually."
        echo "To add zsh to /etc/shells, run:"
        echo "  echo '$zsh_path' | sudo tee -a /etc/shells"
        return 1
    fi
    
    # Change shell
    if command -v chsh >/dev/null 2>&1; then
        echo "Changing default shell to zsh..."
        echo "You may be prompted for your password."
        if chsh -s "$zsh_path"; then
            log_success "Default shell changed to zsh"
            log_warning "You need to log out and back in for the change to take effect"
        else
            log_error "Failed to change default shell"
            echo "You can manually change your shell by running:"
            echo "  chsh -s $zsh_path"
            return 1
        fi
    else
        log_warning "chsh command not found"
        echo "To change your default shell manually, run:"
        echo "  sudo usermod -s $zsh_path $USER"
        return 1
    fi
    
    return 0
}

# Setup shell environment after installation
setup_environment() {
    log_info "Setting up shell environment..."
    
    # Ensure all PATH additions are available in current session
    
    # Add homebrew to PATH if installed
    if [ -d "/home/linuxbrew/.linuxbrew" ]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
        export PATH="/home/linuxbrew/.linuxbrew/bin:$PATH"
    fi
    
    # Add proto to PATH if installed
    if [ -d "$HOME/.local/share/proto/bin" ]; then
        export PATH="$HOME/.local/share/proto/bin:$PATH"
    fi
    
    # Add local bin to PATH
    if [ -d "$HOME/.local/bin" ]; then
        export PATH="$HOME/.local/bin:$PATH"
    fi
    
    # Source zsh environment if .zshenv exists
    if [ -f "$HOME/.zshenv" ]; then
        export ZDOTDIR="$HOME/.config/zsh"
        # Create a temporary file with environment setup
        cat > "/tmp/zsh_env_setup.zsh" << 'EOF'
#!/usr/bin/env zsh
# Temporary environment setup for post-installation

# Source the zshenv to get proper PATH
source ~/.zshenv

# Print current PATH and available commands
echo "Environment setup complete!"
echo "PATH includes:"
echo "$PATH" | tr ':' '\n' | grep -E "(homebrew|proto|local)" | head -5

echo ""
echo "Available commands:"
for cmd in brew proto cargo zsh git starship sheldon eza wezterm; do
    if command -v "$cmd" >/dev/null 2>&1; then
        echo "  ✓ $cmd: $(command -v "$cmd")"
    else
        echo "  ✗ $cmd: not found"
    fi
done
EOF
    fi
    
    echo ""
    log_info "To activate the new environment:"
    echo "  exec zsh"
    echo ""
    echo "Or start a new terminal session"
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
    
    # Report any failed installations
    report_failed_tools
    
    # Setup environment for current session
    setup_environment
    
    # Final status message
    if [ ${#FAILED_TOOLS[@]} -eq 0 ]; then
        log_success "Dotfiles installation complete!"
    else
        log_warning "Dotfiles installation completed with ${#FAILED_TOOLS[@]} failed tool(s)"
    fi
    
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