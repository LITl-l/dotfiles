# Eza

> ⚠️ **DEPRECATED**: This standalone installation script is no longer the recommended approach. The dotfiles repository now manages **eza** via **Nix/Home Manager**.
>
> **Recommended**: Use the main Nix-based configuration which includes eza as a package. See the main [README.md](../README.md) for installation instructions.
>
> This documentation is preserved for reference.

---

Modern replacement for `ls` with colors, icons, and git integration.

## What it does

Eza provides an enhanced directory listing experience with:
- **Colors** for different file types
- **Icons** for visual file type recognition  
- **Git status** indicators
- **Tree view** support
- **Better formatting** and layout options

## Installation

Run the installation script:

```bash
./eza/install.sh
```

### Installation methods

The script tries multiple installation methods in order:

1. **Homebrew** (if available): `brew install eza`
2. **Cargo** (if available): `cargo install eza`
3. **Proto with Cargo**: `proto run cargo -- install eza`

### Requirements

- **Homebrew**: Recommended installation method
- **Or Rust/Cargo**: For building from source
- **Fallback options**: 
  - Install Homebrew: `./homebrew/install.sh`
  - Install build tools and proto: `./install-build-tools.sh && ./proto/install.sh`

## Usage examples

```bash
# Basic listing with colors and icons
eza

# Long format with details
eza -l

# Tree view
eza --tree

# Show git status
eza --git

# All files including hidden
eza -a

# Combine options
eza -la --git --tree
```

## Features

- **Git integration**: Shows file status in repositories
- **Icons**: Visual indicators for file types
- **Colors**: Syntax highlighting for different file types
- **Tree view**: Hierarchical directory display
- **Performance**: Fast and efficient
- **Cross-platform**: Works on Linux, macOS, and Windows