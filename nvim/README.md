# Neovim

Modern Neovim configuration using mini.nvim with LSP, completion, and Git integration.

## What it includes

- **Mini.nvim ecosystem** for lightweight, fast plugins
- **LSP integration** with auto-completion
- **Git integration** with status and operations
- **Fuzzy finding** for files, text, and commands
- **Catppuccin theme** for consistent aesthetics
- **Treesitter** for advanced syntax highlighting

## Installation

Run the installation script:

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

## LSP installation

Auto-install LSP servers using the custom command:

```vim
:LspInstall server-name
```

Example:
```vim
:LspInstall lua-language-server
:LspInstall pyright
```

## Dependencies

- **Neovim 0.9+**: Modern Neovim version
- **Git**: For plugin management
- **Node.js**: For some LSP servers
- **npm**: For LSP server installation
- **ripgrep**: For text search (optional)
- **fd**: For file finding (optional)