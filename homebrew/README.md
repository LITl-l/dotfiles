# Homebrew

Package manager for Linux that provides easy installation of development tools.

## What it does

Homebrew (Linuxbrew) brings the macOS package manager to Linux, offering:
- **Easy package installation** with simple commands
- **Dependency management** that handles requirements automatically
- **Up-to-date packages** maintained by the community
- **Isolated environment** that doesn't interfere with system packages

## Installation

Run the installation script:

```bash
./homebrew/install.sh
```

### What the script does

- **Installs Homebrew** from the official installation script
- **Adds to shell profiles** (.profile, .bashrc, .zshrc)
- **Loads environment** for current session
- **Updates package database**
- **Installs essential packages** automatically

### Essential packages included

The script automatically installs these tools:
- **git**: Version control system
- **curl/wget**: HTTP clients
- **ripgrep**: Fast text search
- **fd**: Fast file finder
- **fzf**: Fuzzy finder
- **bat**: Better cat with syntax highlighting
- **jq/yq**: JSON/YAML processors
- **eza**: Modern ls replacement
- **zoxide**: Smart directory navigation
- **git-delta**: Enhanced diff viewer

## Usage

```bash
# Install a package
brew install package-name

# Update all packages
brew update && brew upgrade

# Search for packages
brew search keyword

# List installed packages
brew list

# Get package info
brew info package-name

# Uninstall a package
brew uninstall package-name
```

## Post-installation

If `brew` command is not found after installation:

1. **Restart your shell** or run:
   ```bash
   eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
   ```

2. **Add to shell profile** manually if needed:
   ```bash
   echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.bashrc
   ```

## Benefits

- **No sudo required** for package installation
- **Latest versions** of development tools
- **Easy cleanup** and removal
- **Cross-platform** consistency with macOS
- **Large package repository** with frequent updates