#!/usr/bin/env bash
#
# WSL WezTerm Configuration Setup Script
#
# This script verifies your WSL WezTerm configuration and provides
# instructions for creating the Windows symlink to access the config.
#
# Usage:
#   ./setup-wsl-wezterm.sh
#
# Options:
#   --help      Show this help message
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WEZTERM_SOURCE="${SCRIPT_DIR}/wezterm"

# Functions
print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

show_help() {
    head -n 9 "$0" | tail -n +2 | sed 's/^# \?//'
    exit 0
}

check_wsl() {
    if ! grep -qi microsoft /proc/version 2>/dev/null; then
        print_error "This script is intended for WSL environments only."
        print_info "Detected OS: $(uname -a)"
        exit 1
    fi
    print_success "WSL environment detected"
}

verify_source() {
    if [[ ! -d "$WEZTERM_SOURCE" ]]; then
        print_error "WezTerm source directory not found: $WEZTERM_SOURCE"
        print_info "Please ensure you're running this script from the dotfiles repository root."
        exit 1
    fi

    if [[ ! -f "$WEZTERM_SOURCE/wezterm.lua" ]]; then
        print_error "WezTerm config file not found: $WEZTERM_SOURCE/wezterm.lua"
        exit 1
    fi

    print_success "WezTerm source directory verified: $WEZTERM_SOURCE"
}

detect_wsl_info() {
    # Detect WSL distribution name
    local wsl_distro
    if [[ -f /etc/os-release ]]; then
        wsl_distro=$(grep -oP '(?<=^ID=).+' /etc/os-release | tr -d '"' | sed 's/^./\U&/')
        # Common mappings
        case "$wsl_distro" in
            Ubuntu) wsl_distro="Ubuntu" ;;
            Nixos) wsl_distro="NixOS" ;;
            Debian) wsl_distro="Debian" ;;
            *) ;;
        esac
    else
        wsl_distro="Ubuntu"  # Default fallback
    fi

    # Get current username
    local username="$USER"

    echo "$wsl_distro|$username"
}

show_windows_instructions() {
    local wsl_info
    wsl_info=$(detect_wsl_info)
    local wsl_distro="${wsl_info%%|*}"
    local username="${wsl_info##*|}"
    local dotfiles_path="${SCRIPT_DIR}"

    echo ""
    print_success "WSL WezTerm configuration verified!"
    echo ""
    print_info "Next steps - Run these commands on Windows:"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  1. Open PowerShell as Administrator"
    echo ""
    echo "  2. Create .config directory if it doesn't exist:"
    echo ""
    echo "     New-Item -ItemType Directory -Path \"\$env:USERPROFILE\\.config\" -Force"
    echo ""
    echo "  3. Create symbolic link to WSL dotfiles wezterm config:"
    echo ""
    echo "     New-Item -ItemType SymbolicLink -Path \"\$env:USERPROFILE\\.config\\wezterm\" -Target \"\\\\wsl\$\\${wsl_distro}\\home\\${username}\\dotfiles\\wezterm\\\""
    echo ""
    echo "     (If your WSL distro name is different, check with: wsl -l -v)"
    echo ""
    echo "  4. Restart WezTerm"
    echo ""
    echo "  5. Verify configuration is loaded (theme, fonts, keybindings should match)"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    print_info "Detected WSL Distribution: ${wsl_distro}"
    print_info "Detected Username: ${username}"
    print_info "Dotfiles Path: ${dotfiles_path}"
    echo ""
    print_warning "If the symlink creation fails, you may need to enable Developer Mode in Windows Settings"
    print_info "Or run PowerShell as Administrator"
    echo ""
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            show_help
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            ;;
    esac
done

# Main execution
main() {
    echo ""
    print_info "WSL WezTerm Configuration Setup"
    echo ""

    check_wsl
    verify_source
    show_windows_instructions
}

main
