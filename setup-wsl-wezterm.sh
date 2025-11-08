#!/usr/bin/env bash
#
# WSL WezTerm Configuration Setup Script
#
# This script automates the setup of WezTerm configuration for WSL environments.
# It creates the proper symbolic link from ~/.config/windows/wezterm to the
# dotfiles wezterm configuration, ensuring Windows WezTerm can access the config.
#
# Usage:
#   ./setup-wsl-wezterm.sh [--force] [--dry-run]
#
# Options:
#   --force     Remove existing configuration without prompting
#   --dry-run   Show what would be done without making changes
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
WEZTERM_SOURCE="${SCRIPT_DIR}/config/wezterm"
WEZTERM_TARGET="${HOME}/.config/windows/wezterm"
FORCE=false
DRY_RUN=false

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
    head -n 15 "$0" | tail -n +2 | sed 's/^# \?//'
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

backup_existing() {
    local target="$1"
    local backup="${target}.backup.$(date +%Y%m%d_%H%M%S)"

    if [[ $DRY_RUN == true ]]; then
        print_info "[DRY RUN] Would backup: $target -> $backup"
        return
    fi

    mv "$target" "$backup"
    print_success "Backed up existing configuration to: $backup"
}

remove_broken_symlink() {
    if [[ $DRY_RUN == true ]]; then
        print_info "[DRY RUN] Would remove: $WEZTERM_TARGET"
        return
    fi

    rm -rf "$WEZTERM_TARGET"
    print_success "Removed broken/existing configuration"
}

handle_existing() {
    local target="$1"

    # Check if it's a symbolic link
    if [[ -L "$target" ]]; then
        local link_target
        link_target="$(readlink -f "$target" 2>/dev/null || echo "broken")"

        if [[ "$link_target" == "$WEZTERM_SOURCE" ]]; then
            print_success "Symlink already correctly configured!"
            print_info "Target: $target -> $WEZTERM_SOURCE"
            return 0
        else
            print_warning "Existing symlink found pointing to different location:"
            print_info "Current: $target -> $(readlink "$target")"
            print_info "Expected: $target -> $WEZTERM_SOURCE"

            if [[ $FORCE == true ]]; then
                remove_broken_symlink
                return 1
            else
                read -rp "Remove and recreate symlink? (y/N): " response
                if [[ "$response" =~ ^[Yy]$ ]]; then
                    remove_broken_symlink
                    return 1
                else
                    print_info "Aborted."
                    exit 0
                fi
            fi
        fi
    # Check if it's a directory
    elif [[ -d "$target" ]]; then
        print_warning "Existing directory found: $target"

        if [[ $FORCE == true ]]; then
            backup_existing "$target"
            return 1
        else
            print_info "Options:"
            print_info "  1) Backup and replace with symlink (recommended)"
            print_info "  2) Remove without backup"
            print_info "  3) Abort"
            read -rp "Choose (1-3): " choice

            case $choice in
                1)
                    backup_existing "$target"
                    return 1
                    ;;
                2)
                    remove_broken_symlink
                    return 1
                    ;;
                *)
                    print_info "Aborted."
                    exit 0
                    ;;
            esac
        fi
    # Check if it's a file
    elif [[ -f "$target" ]]; then
        print_warning "Existing file found: $target"
        backup_existing "$target"
        return 1
    fi

    # Doesn't exist
    return 1
}

create_symlink() {
    local source="$1"
    local target="$2"

    # Create parent directory
    local parent_dir
    parent_dir="$(dirname "$target")"

    if [[ $DRY_RUN == true ]]; then
        print_info "[DRY RUN] Would create directory: $parent_dir"
        print_info "[DRY RUN] Would create symlink: $target -> $source"
        return
    fi

    mkdir -p "$parent_dir"
    print_success "Created directory: $parent_dir"

    # Create symlink using absolute path
    ln -sf "$source" "$target"
    print_success "Created symlink: $target -> $source"
}

verify_symlink() {
    if [[ $DRY_RUN == true ]]; then
        print_info "[DRY RUN] Skipping verification"
        return
    fi

    print_info "Verifying symlink..."

    # Check symlink exists
    if [[ ! -L "$WEZTERM_TARGET" ]]; then
        print_error "Symlink was not created successfully"
        exit 1
    fi

    # Check symlink points to correct location
    local actual_target
    actual_target="$(readlink -f "$WEZTERM_TARGET")"
    if [[ "$actual_target" != "$WEZTERM_SOURCE" ]]; then
        print_error "Symlink points to wrong location"
        print_info "Expected: $WEZTERM_SOURCE"
        print_info "Actual: $actual_target"
        exit 1
    fi

    # Check config file is accessible
    if [[ ! -f "$WEZTERM_TARGET/wezterm.lua" ]]; then
        print_error "Config file not accessible through symlink"
        exit 1
    fi

    print_success "Symlink verified successfully!"
}

show_next_steps() {
    echo ""
    print_success "WSL WezTerm configuration setup complete!"
    echo ""
    print_info "Next steps:"
    echo "  1. On Windows (PowerShell as Administrator), create the bridge symlink:"
    echo "     New-Item -ItemType SymbolicLink -Path \"\$env:USERPROFILE\\.config\" -Target \"\\\\wsl\$\\Ubuntu\\home\\$USER\\.config\\windows\""
    echo ""
    echo "  2. Adjust the WSL distribution name if needed (check with: wsl -l -v)"
    echo ""
    echo "  3. Restart WezTerm on Windows"
    echo ""
    echo "  4. Verify config is loaded by checking WezTerm appearance/settings"
    echo ""
    print_info "For troubleshooting, see README.md section on WSL WezTerm Configuration"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --force)
            FORCE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
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

    if ! handle_existing "$WEZTERM_TARGET"; then
        create_symlink "$WEZTERM_SOURCE" "$WEZTERM_TARGET"
    fi

    verify_symlink
    show_next_steps
}

main
