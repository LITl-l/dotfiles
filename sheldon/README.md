# Sheldon

> ⚠️ **DEPRECATED**: This Sheldon configuration is no longer used. The dotfiles repository has migrated to **Fish shell** with native plugin management via **Nix/Home Manager**.
>
> **Recommended**: Use the main Nix-based configuration which manages Fish plugins declaratively. See the main [README.md](../README.md) for installation instructions.
>
> This documentation is preserved for reference.

---

Fast Zsh plugin manager written in Rust.

## What it does

Sheldon provides efficient Zsh plugin management with:
- **Fast loading** of plugins and themes
- **Git-based** plugin sources
- **Template system** for conditional loading
- **Deferred loading** for better startup performance
- **Simple configuration** in TOML format

## Installation

Run the installation script:

```bash
./sheldon/install.sh
```

## Plugins included

### Core functionality
- **zsh-completions**: Additional completion definitions
- **zsh-autosuggestions**: Fish-like command suggestions
- **zsh-syntax-highlighting**: Command syntax highlighting
- **zsh-history-substring-search**: History search with arrows
- **zsh-abbr**: Fish-like abbreviations
- **fzf-tab**: Fuzzy tab completion

### Navigation and utilities
- **zsh-z**: Fast directory jumping (z command)

### Framework plugins (from Oh My Zsh)
- **git**: Git aliases and functions
- **docker**: Docker aliases and completion
- **kubectl**: Kubernetes completion
- **tmux**: Tmux integration

## Configuration

The `plugins.toml` file defines all plugins:

```toml
[plugins.zsh-autosuggestions]
github = "zsh-users/zsh-autosuggestions"
use = ["{{ name }}.zsh"]

[plugins.fzf-tab]
github = "Aloxaf/fzf-tab"
```

### Key features

- **GitHub sources**: Direct plugin installation from repositories
- **Selective loading**: Choose specific files with `use` parameter
- **Template support**: Dynamic configuration with deferred loading
- **Shell targeting**: Configured specifically for Zsh

## Usage

```bash
# Lock and install plugins
sheldon lock

# Add a new plugin
sheldon add plugin-name --git https://github.com/user/repo

# List installed plugins
sheldon list

# Update all plugins
sheldon lock --update

# Remove a plugin
sheldon remove plugin-name
```

## Performance features

### Deferred loading
- **zsh-defer**: Plugins load in background for faster startup
- **Template system**: Conditional plugin loading
- **Lazy evaluation**: Plugins load only when needed

### Environment integration
- **Sheldon config**: Located in `$XDG_CONFIG_HOME/sheldon`
- **Data directory**: `$XDG_DATA_HOME/sheldon`
- **Auto-init**: Configured in Zsh startup files

## Plugin highlights

**zsh-autosuggestions**: 
- Shows command suggestions based on history
- Accept with right arrow or end key

**fzf-tab**:
- Fuzzy searching in tab completion
- Visual selection with preview

**zsh-syntax-highlighting**:
- Real-time command syntax validation
- Color-coded command status

**zsh-abbr**:
- Fish-like abbreviations that expand on space
- Custom command shortcuts