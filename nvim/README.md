# Neovim

Modern Neovim configuration using mini.nvim with LSP, completion, and Git integration.

> **Managed by Nix**: This configuration is automatically managed by the main Nix flakes setup. See [modules/neovim.nix](../modules/neovim.nix) for the Nix configuration. No manual installation required when using the main dotfiles setup.

## What it includes

- **Mini.nvim ecosystem** for lightweight, fast plugins
- **LSP integration** with auto-completion
- **Git integration** with status and operations
- **Fuzzy finding** for files, text, and commands
- **Catppuccin theme** for consistent aesthetics
- **Treesitter** for advanced syntax highlighting
- **Vi mode everywhere** consistent with Fish and Tmux

## Installation

### Via Nix (Recommended)

Neovim is automatically installed and configured when you use the main dotfiles setup:

```bash
# See main README for full installation
home-manager switch --flake ~/dotfiles
```

The configuration files in this directory are automatically symlinked by the Nix module.

### Standalone (Legacy)

If you need just neovim configuration without the full Nix setup:

```bash
./nvim/install.sh
```

## Key features

### Plugin management
- **Mini.deps**: Automatic plugin management
- **Lazy loading**: Plugins load when needed
- **Bootstrap**: Auto-installs mini.nvim on first run
- **No external dependencies**: Self-contained setup

### LSP servers supported
- **lua_ls**: Lua language server
- **pyright**: Python type checking
- **rust_analyzer**: Rust language support
- **tsserver**: TypeScript/JavaScript
- **gopls**: Go language server
- **bashls**: Bash scripting
- **jsonls/yamlls**: Configuration files
- **html/cssls**: Web development
- **dockerls**: Docker files
- **terraformls**: Infrastructure as code

### Key mappings

**File navigation:**
- `<leader>e`: Open file explorer (current directory)
- `<leader>E`: Open file explorer (current file location)

**Fuzzy finding:**
- `<leader>ff`: Find files
- `<leader>fg`: Live grep (search text)
- `<leader>fb`: Find buffers
- `<leader>fh`: Find help topics
- `<leader>fr`: Recent files
- `<leader>fd`: Find diagnostics
- `<leader>fk`: Find keymaps
- `<leader>fc`: Find commands
- `<leader>fm`: Find marks
- `<leader>fo`: Find options

### Configuration structure

```
nvim/
├── init.lua              # Main configuration entry
├── install.sh           # Installation script
└── lua/config/
    ├── autocmds.lua     # Auto commands
    ├── keymaps.lua      # Key mappings
    ├── options.lua      # Neovim options
    ├── plugins.lua      # Plugin configurations
    └── util.lua         # Utility functions
```

## Plugin ecosystem

### Core functionality
- **mini.files**: File explorer with edit capabilities
- **mini.pick**: Fuzzy finder and picker
- **mini.completion**: Auto-completion engine
- **mini.git**: Git integration and status

### Visual enhancements
- **Catppuccin**: Color scheme
- **Treesitter**: Syntax highlighting
- **mini.statusline**: Status bar (optional)
- **mini.icons**: File type icons

### Code features
- **LSP**: Language server integration
- **Diagnostics**: Error and warning display
- **Formatting**: Code formatting support
- **Snippets**: Code snippet expansion

## LSP servers

LSP servers are managed entirely by Nix and installed via the `modules/neovim.nix` configuration. No manual installation is required.

The configuration automatically enables LSP servers that are found in PATH. To add or remove LSP servers, edit the `extraPackages` section in `modules/neovim.nix`:

```nix
extraPackages = with pkgs; [
  lua-language-server
  nil                                          # Nix LSP
  nodePackages.bash-language-server
  nodePackages.typescript-language-server
  nodePackages.vscode-langservers-extracted    # HTML, CSS, JSON
  nodePackages.yaml-language-server
  python3Packages.python-lsp-server
  rust-analyzer
  gopls
];
```

After modifying, rebuild with:

```bash
home-manager switch --flake ~/dotfiles
```

## Dependencies

All dependencies are managed by Nix. When using the Nix setup, no manual installation is required.

For standalone usage (legacy):
- **Neovim 0.9+**: Modern Neovim version
- **Git**: For plugin management
- **ripgrep**: For text search
- **fd**: For file finding
