# Git Configuration

Comprehensive Git configuration with aliases, Delta pager, and optimized settings.

> **Managed by Nix**: This configuration is automatically managed by the main Nix flakes setup. See [modules/git.nix](../modules/git.nix) for the Nix configuration. No manual installation required when using the main dotfiles setup.

## What it includes

- **Modern Git aliases** for common operations
- **Delta pager** for beautiful diffs with syntax highlighting
- **Lazygit** Terminal UI with Catppuccin theme
- **LFS support** for large files
- **Smart defaults** and optimizations
- **Global gitignore** for common patterns

## Installation

### Via Nix (Recommended)

Git configuration is automatically set up when you use the main dotfiles setup:

```bash
# See main README for full installation
home-manager switch --flake ~/dotfiles
```

The Nix configuration includes git, delta, and lazygit all configured to work together.

### Standalone (Legacy)

If you need just git configuration without the full Nix setup:

```bash
./git/install.sh
```

## Key features

### Aliases

**Status and branch management:**
```bash
git s          # Short status
git st         # Full status  
git br         # List branches
git co         # Checkout
git cob        # Checkout new branch
```

**Commit operations:**
```bash
git c          # Commit
git cm         # Commit with message
git ca         # Amend last commit
git can        # Amend without editing message
```

**Advanced log views:**
```bash
git l          # One-line graph
git lg         # Pretty graph with colors
git ll         # Detailed log with stats
```

**Remote operations:**
```bash
git f          # Fetch
git pl         # Pull with rebase
git ps         # Push
git psu        # Push and set upstream
```

### Delta pager configuration

- **Syntax highlighting** with Catppuccin theme
- **Line numbers** for better navigation
- **Side-by-side diffs** (configurable)
- **Git integration** for interactive commands

### Smart defaults

- **Auto-rebase** on pull
- **Auto-prune** on fetch
- **Fast-forward only** merges
- **Histogram diff** algorithm
- **Credential caching** (1 hour)

## Configuration files

- **config**: Main Git configuration
- **ignore**: Global gitignore patterns
- **attributes**: Git attributes for file handling
- **config.local**: Local user settings (not tracked)

## User setup

Create `~/.config/git/config.local` with your details:

```ini
[user]
    name = Your Name
    email = your.email@example.com
```

## Dependencies

- **Delta**: For enhanced diff viewing
- **Git LFS**: For large file support (optional)