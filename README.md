# Dotfiles

A comprehensive, XDG-compliant dotfiles repository with modular tool configurations for a modern Linux development environment.

## 🚀 Features

- **Modular structure** - Each tool has its own directory with individual install scripts
- **XDG Base Directory Specification compliant** - All configurations follow the XDG standard
- **Flexible installation** - Install all tools or pick specific ones
- **Modern tool stack** - Using the latest and greatest CLI tools
- **Vim-centric workflow** - Vi mode in shell and consistent keybindings
- **Performance focused** - Fast shell prompt, efficient completions

## 📦 Included Tools

### Shell Environment
- **[zsh/](zsh/)** - Modern shell with vi mode enabled
- **[sheldon/](sheldon/)** - Fast plugin manager for Zsh
- **[starship/](starship/)** - Blazing fast, customizable prompt

### Terminal & Editor
- **[wezterm/](wezterm/)** - GPU-accelerated terminal emulator
- **[nvim/](nvim/)** - Hyperextensible Vim-based text editor with mini.nvim
- **[tmux/](tmux/)** - Terminal multiplexer with custom theme

### Development Tools
- **[homebrew/](homebrew/)** - Package manager for Linux
- **[proto/](proto/)** - Multi-language toolchain manager
- **[docker/](docker/)** - Containerization platform setup
- **[git/](git/)** - Version control with delta for better diffs
- **[lazygit/](lazygit/)** - Terminal UI for git commands

### CLI Utilities
- **[eza/](eza/)** - Modern replacement for ls

## 🛠️ Installation

### Prerequisites

- Linux-based operating system (tested on Ubuntu 22.04+, Debian 11+)
- `curl` and `git` installed
- `sudo` access (for Docker setup)

### Quick Install (All Tools)

```bash
git clone https://github.com/yourusername/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

### Install Specific Tools

```bash
# Install only specific tools
./install.sh zsh git nvim tmux

# List available tools
./install.sh --list

# Get help
./install.sh --help
```

### Install Individual Tools

Each tool can be installed independently:

```bash
# Install just Zsh configuration
./zsh/install.sh

# Install just Neovim configuration
./nvim/install.sh

# Install just Git configuration
./git/install.sh
```

## 📁 Directory Structure

```
dotfiles/
├── install.sh              # Main installation script
├── README.md               # This file
│
├── zsh/                    # Zsh configuration
│   ├── .zshenv            # Zsh environment file (links to ~/.zshenv)
│   ├── .zshrc             # Main Zsh configuration
│   ├── abbreviations.zsh  # Shell abbreviations (via zsh-abbr)
│   ├── functions.zsh      # Custom functions
│   ├── env.zsh            # Environment variables
│   └── install.sh         # Zsh installation script
│
├── git/                    # Git configuration
│   ├── config             # Git configuration
│   ├── ignore             # Global gitignore
│   ├── attributes         # Git attributes
│   └── install.sh         # Git installation script
│
├── lazygit/                # Lazygit configuration
│   ├── config.yml         # Lazygit configuration
│   └── install.sh         # Lazygit installation script
│
├── nvim/                   # Neovim configuration
│   ├── init.lua           # Neovim configuration with mini.nvim
│   └── install.sh         # Neovim installation script
│
├── tmux/                   # Tmux configuration
│   ├── tmux.conf          # Tmux configuration
│   └── install.sh         # Tmux installation script
│
├── wezterm/                # WezTerm configuration
│   ├── wezterm.lua        # WezTerm configuration
│   └── install.sh         # WezTerm installation script
│
├── starship/               # Starship configuration
│   ├── starship.toml      # Starship prompt configuration
│   └── install.sh         # Starship installation script
│
├── sheldon/                # Sheldon configuration
│   ├── plugins.toml       # Zsh plugin definitions
│   └── install.sh         # Sheldon installation script
│
├── homebrew/               # Homebrew setup
│   └── install.sh         # Homebrew installation script
│
├── proto/                  # Proto toolchain manager
│   └── install.sh         # Proto installation script
│
├── docker/                 # Docker setup
│   └── install.sh         # Docker configuration script
│
└── eza/                    # Eza configuration
    └── install.sh         # Eza installation script
```

## ⚙️ Configuration Details

### Environment Variables

The following XDG environment variables are set:

```bash
XDG_CONFIG_HOME="$HOME/.config"
XDG_DATA_HOME="$HOME/.local/share"
XDG_STATE_HOME="$HOME/.local/state"
XDG_CACHE_HOME="$HOME/.cache"
```

### Zsh

- Vi mode enabled with visual mode indicators
- Fast syntax highlighting and autosuggestions
- Abbreviation support (like fish shell)
- Smart completions with fzf integration
- Custom aliases and functions

Key bindings:
- `Ctrl+R` - Fuzzy search command history
- `Ctrl+T` - Fuzzy find files
- `Alt+C` - Fuzzy cd to directory
- `v` (in normal mode) - Edit command in Neovim

### Neovim

Configured with mini.nvim for a minimal yet powerful setup:
- File explorer with preview
- Fuzzy finder for files, buffers, and grep
- Git integration
- LSP support ready
- Treesitter for syntax highlighting
- Catppuccin color scheme

Key bindings:
- `<Space>` - Leader key
- `<Space>e` - File explorer
- `<Space>ff` - Find files
- `<Space>fg` - Live grep
- `<Space>w` - Save file

### Tmux

- Custom Catppuccin-inspired theme
- Vi mode for copy/paste
- Smart pane switching
- Session persistence
- Mouse support

Key bindings:
- `Ctrl+a` - Prefix key
- `Prefix |` - Split vertically
- `Prefix -` - Split horizontally
- `Prefix h/j/k/l` - Navigate panes
- `Prefix H/J/K/L` - Resize panes

### Git

- Delta for better diffs
- Useful aliases
- Global gitignore
- Auto-setup remote tracking

### WezTerm

- GPU accelerated rendering
- Catppuccin color scheme
- Custom key bindings
- Multiplexing support

## 🔧 Customization

### Adding Your Git Identity

Create `~/.config/git/config.local`:

```ini
[user]
    name = Your Name
    email = your.email@example.com
```

### Local Zsh Configuration

Create `~/.config/zsh/.zshrc.local` for machine-specific settings.

### Additional Sheldon Plugins

Edit the `sheldon/plugins.toml` file to add more Zsh plugins.

## 🐛 Troubleshooting

### Tool-specific Issues

Each tool directory contains its own installation script. If a specific tool fails to install or configure:

```bash
# Re-run the specific tool installation
./TOOL_NAME/install.sh
```

### Common Issues

#### Zsh not set as default shell

```bash
chsh -s $(which zsh)
```

Then log out and back in.

#### Docker permission denied

```bash
sudo usermod -aG docker $USER
```

Then log out and back in.

#### Fonts not displaying correctly

Install a Nerd Font:
```bash
brew tap homebrew/cask-fonts
brew install --cask font-jetbrains-mono-nerd-font
```

#### Neovim plugins not installing

```vim
:Lazy sync
```

## 📝 Adding New Tools

To add a new tool to the dotfiles:

1. Create a new directory for the tool
2. Add configuration files
3. Create an `install.sh` script that:
   - Installs the tool if not present
   - Links configuration files
   - Sets up any required directories
4. Add the tool to the `tools` array in the main `install.sh`

Example structure:
```
new-tool/
├── config-file
└── install.sh
```

## 📝 License

This project is licensed under the MIT License.

## 🤝 Contributing

Feel free to submit issues and pull requests!

## 🙏 Acknowledgments

- [XDG Base Directory Specification](https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html)
- [Catppuccin](https://github.com/catppuccin/catppuccin) for the color scheme
- All the amazing open source tool maintainers