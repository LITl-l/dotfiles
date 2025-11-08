# Starship

Cross-shell prompt with rich context and beautiful design.

> **Managed by Nix**: This configuration is automatically managed by the main Nix flakes setup. See [modules/starship.nix](../modules/starship.nix) for the Nix configuration. No manual installation required when using the main dotfiles setup.

## What it does

Starship provides an intelligent, context-aware shell prompt featuring:
- **Git integration** with status, branch, and metrics
- **Language detection** for Node.js, Python, Rust, Go, etc.
- **Directory navigation** with smart truncation
- **Performance monitoring** with command duration
- **Cloud context** for AWS, Docker, Kubernetes
- **Nix shell** indicator for development environments

## Installation

### Via Nix (Recommended)

Starship is automatically installed and configured when you use the main dotfiles setup:

```bash
# See main README for full installation
home-manager switch --flake ~/dotfiles
```

The Nix configuration automatically integrates Starship with Fish shell and sets up all necessary environment variables.

### Standalone (Legacy)

If you need just starship configuration without the full Nix setup:

```bash
./starship/install.sh
```

## Key features

### Git integration
- **Branch display** with remote tracking
- **Status indicators**: staged, modified, untracked files
- **Ahead/behind** commit indicators
- **State display**: merge, rebase, cherry-pick status
- **Metrics**: Added/deleted line counts

### Language detection
**Automatically shows versions for:**
- **Node.js**: With npm/package.json detection
- **Python**: With virtual environment support
- **Rust**: With Cargo.toml detection
- **Go**: With go.mod detection
- **Docker**: With Dockerfile/compose detection

### Visual enhancements
- **Catppuccin-inspired** color scheme
- **Nerd Font icons** for file types and tools
- **Two-line prompt** with clean separation
- **Directory substitutions** for common paths
- **Time display** on right side

## Prompt structure

```
┌ user@host ~/Projects/repo  main +2 !1 [+15 -3] ○ node 18.17.0  1.2s 16:30
└ ❯
```

**Components:**
- **User/host**: Only on SSH connections
- **Directory**: With smart truncation and icons
- **Git**: Branch, status, and metrics
- **Languages**: Detected tools and versions
- **Duration**: Command execution time
- **Time**: Current time on right

## Configuration highlights

### Directory customization
```toml
[directory.substitutions]
"~/Documents" = "󰈙"
"~/Projects" = "󰲋" 
"~/src" = ""
```

### Git status symbols
- **?**: Untracked files
- **+**: Staged changes
- **!**: Modified files
- **✘**: Deleted files
- **$**: Stashed changes
- **⇡⇣**: Ahead/behind commits

### Language configurations
- **Auto-detection** based on project files
- **Version display** when in project directory
- **Virtual environment** support for Python
- **Toolchain awareness** for Rust/Cargo

## Performance

- **Fast rendering**: Minimal latency
- **Async modules**: Non-blocking information gathering
- **Smart caching**: Reduces redundant checks
- **Configurable timeout**: 1000ms maximum per module

## Environment setup

Configured via Nix Home Manager ([modules/starship.nix](../modules/starship.nix)):
- **Shell integration**: Auto-initialized in Fish shell
- **Configuration**: Declaratively defined in Nix
- **Cross-platform**: Works on Linux, macOS, and WSL2

## Customization

When using the Nix setup, configuration is in `modules/starship.nix`:
- **Module ordering** and visibility
- **Color schemes** and styling
- **Detection logic** for languages
- **Prompt format** and layout

All settings are declared in Nix format and automatically applied when you rebuild your configuration:

```bash
# Edit modules/starship.nix, then:
home-manager switch --flake ~/dotfiles
```