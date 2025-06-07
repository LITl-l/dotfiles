#!/usr/bin/env bash

# Local test script for dotfiles installation
# This script can be run locally to verify installation works correctly

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

run_test() {
    local test_name="$1"
    local test_command="$2"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    log_info "Running test: $test_name"
    
    if eval "$test_command"; then
        log_success "✅ $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_error "❌ $test_name"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    echo ""
}

# Backup existing configs
backup_configs() {
    log_info "Backing up existing configurations..."
    mkdir -p /tmp/dotfiles-backup
    
    # Backup files that might exist
    for file in ~/.zshenv ~/.config/git/config ~/.config/zsh; do
        if [ -e "$file" ]; then
            cp -r "$file" "/tmp/dotfiles-backup/$(basename "$file")" 2>/dev/null || true
        fi
    done
    
    log_success "Configurations backed up to /tmp/dotfiles-backup"
}

# Restore configs
restore_configs() {
    log_info "Restoring original configurations..."
    
    # Remove test installations
    rm -f ~/.zshenv
    rm -rf ~/.config/zsh
    rm -f ~/.config/git/config
    
    # Restore from backup
    for file in /tmp/dotfiles-backup/*; do
        if [ -e "$file" ]; then
            filename=$(basename "$file")
            case "$filename" in
                ".zshenv") cp "$file" ~/.zshenv ;;
                "config") mkdir -p ~/.config/git && cp "$file" ~/.config/git/config ;;
                "zsh") cp -r "$file" ~/.config/zsh ;;
            esac
        fi
    done
    
    log_success "Original configurations restored"
}

# Test script syntax
test_syntax() {
    log_info "Testing script syntax..."
    
    run_test "Main install script syntax" "bash -n install.sh"
    run_test "Build tools script syntax" "bash -n install-build-tools.sh"
    
    # Test all tool install scripts
    for script in */install.sh; do
        if [ -f "$script" ]; then
            run_test "$script syntax" "bash -n '$script'"
        fi
    done
}

# Test install script options
test_options() {
    log_info "Testing install script options..."
    
    run_test "Help option" "./install.sh --help >/dev/null"
    run_test "List option" "./install.sh --list >/dev/null"
}

# Test individual tool installation
test_individual_tools() {
    log_info "Testing individual tool installations..."
    
    # Test git installation
    run_test "Git installation" "
        ./install.sh git >/dev/null 2>&1 && 
        [ -f ~/.config/git/config ]
    "
    
    # Test zsh installation
    run_test "Zsh configuration" "
        ./install.sh zsh >/dev/null 2>&1 && 
        [ -f ~/.zshenv ] && 
        [ -f ~/.config/zsh/.zshrc ] &&
        [ -f ~/.config/zsh/env.zsh ]
    "
}

# Test basic functionality
test_basic_functionality() {
    log_info "Testing basic functionality..."
    
    # Test that install.sh is executable and available
    run_test "Install script availability" "
        [ -x ./install.sh ]
    "
    
    # Test basic installation with git (simple and reliable)
    run_test "Basic tool installation" "
        ./install.sh git >/dev/null 2>&1 && 
        [ -f ~/.config/git/config ]
    "
}

# Test XDG directory creation
test_xdg_directories() {
    log_info "Testing XDG directory creation..."
    
    run_test "XDG directories created" "
        ./install.sh git >/dev/null 2>&1 &&
        [ -d ~/.config ] && 
        [ -d ~/.local/share ] && 
        [ -d ~/.local/state ] && 
        [ -d ~/.cache ] && 
        [ -d ~/.local/bin ]
    "
}

# Main test execution
main() {
    echo "🧪 Dotfiles Installation Test Suite"
    echo "=================================="
    echo ""
    
    # Check if we're in the right directory
    if [ ! -f "install.sh" ]; then
        log_error "Please run this script from the dotfiles directory"
        exit 1
    fi
    
    # Backup existing configs
    backup_configs
    
    # Run tests
    test_syntax
    test_options
    test_individual_tools
    test_basic_functionality
    test_xdg_directories
    
    # Restore configs
    restore_configs
    
    # Test summary
    echo ""
    echo "📊 Test Summary"
    echo "=============="
    echo "Tests run: $TESTS_RUN"
    echo "Passed: $TESTS_PASSED"
    echo "Failed: $TESTS_FAILED"
    echo ""
    
    if [ $TESTS_FAILED -eq 0 ]; then
        log_success "All tests passed! 🎉"
        exit 0
    else
        log_error "Some tests failed. Please review the output above."
        exit 1
    fi
}

# Run main function
main "$@"