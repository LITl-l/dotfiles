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
- **Built-in tutor** (`:Dojo`) that teaches and drills this config's own keymaps

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
- **Lazy loading**: Heavy plugins load on first relevant event or keypress
- **Bootstrap**: Nix provides mini.nvim; standalone installs still auto-bootstrap it
- **Nix-managed dependencies**: Home Manager provides plugins/tools; heavy plugins are installed optional and loaded on demand

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

**LSP diagnostics:**
- `<leader>cd`: Show line diagnostics
- `<leader>cl`: Open diagnostics list

### Tutor (`:Dojo`)

A tutor for this config specifically, not for generic Vim.

- `<leader>tt` -- chaptered lessons
- `<leader>td` -- timed drills, weakest keymaps first
- `<leader>ts` -- your keystroke-ratio stats

Lesson chapters are generated from the live keymap table
(`nvim_get_keymap` plus `nvim_buf_get_keymap` for the buffer-local LSP maps), so
they cannot drift from the config. Drill exercises are authored, but each pins a
keymap that `nvim/tests/tutor.lua` asserts still resolves -- a renamed or deleted
map fails `nix flake check` instead of leaving a drill for a dead key.

Progress lives in `$XDG_STATE_HOME/nvim/tutor/progress.json`.

### Configuration structure

```
nvim/
├── init.lua              # Main configuration entry
├── install.sh            # Installation script
├── tests/                # headless assertions run by nix flake check
├── lua/config/
│   ├── autocmds.lua      # Auto commands
│   ├── keymaps.lua       # Key mappings
│   ├── options.lua       # Neovim options
│   ├── plugins.lua       # Plugin configurations
│   └── util.lua          # Utility functions
└── lua/tutor/
    ├── init.lua          # :Dojo API and dispatch
    ├── inventory.lua     # keymaps derived from the live table
    ├── lessons.lua       # chapters over the inventory
    ├── drills.lua        # authored, pinned drill corpus
    ├── session.lua       # engine: keystroke count, timing, scoring
    ├── progress.lua      # progress persistence and ranking
    └── ui.lua            # floats and briefings
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
- **nvim-lspconfig**: Language server defaults
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
