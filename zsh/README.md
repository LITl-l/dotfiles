# Zsh Configuration

> ⚠️ **DEPRECATED**: This Zsh configuration is no longer actively maintained. The dotfiles repository has migrated to **Fish shell** with **Nix/Home Manager** for declarative configuration management.
>
> **Recommended**: Use the main Nix-based configuration which includes Fish shell. See the main [README.md](../README.md) for installation instructions.
>
> This documentation is preserved for reference and for users who may still want a bash-based Zsh setup.

---

Modern Zsh setup with plugins, completions, and development tools integration.

## What it includes

- **Plugin management** via Sheldon for fast loading
- **Starship prompt** with rich context awareness
- **Development tools** integration (Git, Docker, Kubernetes)
- **Environment management** with XDG compliance
- **Alias system** for productivity
- **Smart completions** and suggestions

## Installation

Run the installation script:

```bash
./zsh/install.sh
```

## File structure

```
zsh/
├── install.sh           # Installation script
├── env.zsh             # Environment variables and paths
├── functions.zsh       # Custom functions
└── abbreviations.zsh   # Command abbreviations/aliases
```

## Key features

### Environment setup (`env.zsh`)

**XDG Base Directory compliance:**
- **Config**: `$XDG_CONFIG_HOME` (~/.config)
- **Data**: `$XDG_DATA_HOME` (~/.local/share)
- **Cache**: `$XDG_CACHE_HOME` (~/.cache)
- **State**: `$XDG_STATE_HOME` (~/.local/state)

**Tool configurations:**
- **Proto**: Toolchain manager paths
- **Starship**: Prompt configuration
- **Docker**: Config directory
- **Cargo/Rust**: Data directories
- **History**: 50,000 lines in XDG location

**PATH management:**
- **Local bin**: `~/.local/bin`
- **Cargo**: Rust packages
- **Proto**: Toolchain shims
- **Homebrew**: Linux package manager

### Functions (`functions.zsh`)

**Development utilities:**
- **Project navigation**: Quick directory jumping
- **Git helpers**: Enhanced git operations
- **File operations**: Batch file handling
- **System info**: Quick system status

### Abbreviations (`abbreviations.zsh`)

**Git shortcuts:**
- **gs**: git status
- **ga**: git add
- **gc**: git commit
- **gp**: git push
- **gl**: git pull

**Docker shortcuts:**
- **d**: docker
- **dc**: docker-compose
- **dps**: docker ps
- **dlogs**: docker logs

**System shortcuts:**
- **ll**: eza -la (detailed listing)
- **la**: eza -a (all files)
- **lt**: eza --tree (tree view)
- **lg**: lazygit

## Plugin integration

### Via Sheldon
- **Fast loading**: Rust-based plugin manager
- **Deferred loading**: Plugins load in background
- **Oh My Zsh plugins**: Git, Docker, Kubectl
- **Community plugins**: Autosuggestions, syntax highlighting

### Core plugins
- **zsh-autosuggestions**: Command suggestions from history
- **zsh-syntax-highlighting**: Real-time syntax validation
- **fzf-tab**: Fuzzy tab completion
- **zsh-z**: Smart directory navigation

## Development tools integration

### Version managers
- **Proto**: Universal toolchain manager
- **PATH priority**: Tools available via shims
- **Project detection**: Automatic version switching

### Shell enhancements
- **FZF**: Fuzzy finding for files and commands
- **Zoxide**: Smart cd replacement
- **Eza**: Modern ls with git integration
- **Bat**: Syntax-highlighted cat

### Editor integration
- **Nvim**: Default editor and visual
- **Git editor**: Configured for commits
- **Less pager**: Enhanced viewing

## Performance optimizations

### Fast startup
- **Sheldon**: Efficient plugin loading
- **Deferred plugins**: Background initialization
- **Minimal config**: Essential-only startup
- **Plugin caching**: Reduced load times

### History management
- **Large capacity**: 50,000 commands
- **Smart search**: Substring matching
- **Shared history**: Across all sessions
- **XDG compliance**: Organized storage

## Environment variables

### Development
- **EDITOR/VISUAL**: Neovim
- **PAGER**: Less with smart options
- **BROWSER**: System default

### Tools
- **FZF_DEFAULT_COMMAND**: Uses fd for file finding
- **LESS**: Optimized viewing options
- **DOCKER_CONFIG**: XDG compliant location

### Language-specific
- **CARGO_HOME**: Rust package manager
- **RUSTUP_HOME**: Rust toolchain
- **GHQ_ROOT**: Git repository management

## Usage tips

1. **Use abbreviations**: Type shortcuts for common commands
2. **Tab completion**: Enhanced with fzf integration
3. **History search**: Use arrow keys for substring search
4. **Directory jumping**: Use z command for smart navigation
5. **Git integration**: Leverage built-in git aliases and functions