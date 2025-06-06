# Dotfiles

A comprehensive, XDG-compliant dotfiles repository for a modern Linux development environment.

## 🚀 Features

- **XDG Base Directory Specification compliant** - All configurations follow the XDG standard
- **Automated installation** - Single script to set up everything
- **Modern tool stack** - Using the latest and greatest CLI tools
- **Vim-centric workflow** - Vi mode in shell and consistent keybindings
- **Performance focused** - Fast shell prompt, efficient completions

## 📦 Included Tools

### Shell Environment
- **Zsh** - Modern shell with vi mode enabled
- **Sheldon** - Fast plugin manager for Zsh
- **Starship** - Blazing fast, customizable prompt
- **Zoxide** - Smarter cd command that learns your habits

### Terminal & Editor
- **WezTerm** - GPU-accelerated terminal emulator
- **Neovim** - Hyperextensible Vim-based text editor with mini.nvim
- **Tmux** - Terminal multiplexer with custom theme

### Development Tools
- **Homebrew** - Package manager for Linux
- **Proto** - Multi-language toolchain manager
- **Docker** - Containerization platform
- **Git** - Version control with delta for better diffs
- **ghq** - Repository organizer

### CLI Utilities
- **eza** - Modern replacement for ls
- **fzf** - Fuzzy finder for everything
- **ripgrep** - Fast grep alternative
- **fd** - Fast find alternative
- **bat** - Cat with syntax highlighting
- **delta** - Better git diffs

## 🛠️ Installation

### Prerequisites

- Linux-based operating system (tested on Ubuntu 22.04+, Debian 11+)
- `curl` and `git` installed
- `sudo` access (for Docker setup)

### Quick Install

```bash
git clone https://github.com/yourusername/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

The installation script will:
1. Create XDG directory structure
2. Install Homebrew (if not present)
3. Install all tools and dependencies
4. Create symbolic links for configurations
5. Set Zsh as the default shell
6. Configure Docker permissions

### Manual Installation

If you prefer to install components individually:

```bash
# Create XDG directories
mkdir -p ~/.config ~/.local/share ~/.local/state ~/.cache ~/.local/bin

# Link individual configurations
ln -sf ~/dotfiles/config/zsh ~/.config/zsh
ln -sf ~/dotfiles/config/nvim ~/.config/nvim
# ... repeat for other tools

# Install tools manually
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install zsh starship eza tmux neovim
cargo install sheldon zoxide
# ... etc
```

## 📁 Directory Structure

```
dotfiles/
├── .zshenv                    # Zsh environment (sourced first)
├── config/                    # XDG_CONFIG_HOME
│   ├── zsh/                   # Zsh configuration
│   │   ├── .zshenv           # Environment variables
│   │   ├── .zshrc            # Interactive shell config
│   │   ├── aliases.zsh       # Shell aliases
│   │   └── functions.zsh     # Shell functions
│   ├── sheldon/              # Plugin manager
│   │   └── plugins.toml      # Plugin definitions
│   ├── starship/             # Prompt configuration
│   │   └── starship.toml
│   ├── wezterm/              # Terminal configuration
│   │   └── wezterm.lua
│   ├── nvim/                 # Neovim configuration
│   │   └── init.lua
│   ├── tmux/                 # Tmux configuration
│   │   └── tmux.conf
│   ├── git/                  # Git configuration
│   │   ├── config
│   │   ├── ignore
│   │   └── attributes
│   └── eza/                  # eza configuration
├── local/                    # XDG_DATA_HOME
│   ├── share/
│   ├── state/
│   └── bin/
├── cache/                    # XDG_CACHE_HOME
└── install.sh               # Installation script
```

## ⚙️ Configuration

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

Edit `~/.config/sheldon/plugins.toml` to add more Zsh plugins.

## 🐛 Troubleshooting

### Zsh not set as default shell

```bash
chsh -s $(which zsh)
```

Then log out and back in.

### Docker permission denied

```bash
sudo usermod -aG docker $USER
```

Then log out and back in.

### Fonts not displaying correctly

Install a Nerd Font:
```bash
brew tap homebrew/cask-fonts
brew install --cask font-jetbrains-mono-nerd-font
```

### Neovim plugins not installing

```vim
:Lazy sync
```

## 📝 License

This project is licensed under the MIT License.

## 🤝 Contributing

Feel free to submit issues and pull requests!

## 🙏 Acknowledgments

- [XDG Base Directory Specification](https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html)
- [Catppuccin](https://github.com/catppuccin/catppuccin) for the color scheme
- All the amazing open source tool maintainers