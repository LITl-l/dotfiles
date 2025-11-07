# Dotfiles

A declarative, reproducible dotfiles configuration using Nix and Home Manager. Works on Linux, macOS, and WSL2.

## 🚀 Features

- **Declarative Configuration** - Everything defined in Nix for reproducibility
- **Cross-Platform** - Works on Linux, macOS, and WSL2
- **Home Manager** - Manages user environment with Nix
- **Modern Tool Stack** - Latest CLI tools and applications
- **Vi Mode Everything** - Consistent vi keybindings across all tools
- **GPU-Accelerated Terminal** - WezTerm with cross-platform support
- **Automated CI** - GitHub Actions validates all configurations

## 📦 Included Tools

### Shell Environment
- **Fish** - Modern shell with vi mode and excellent autosuggestions
- **Starship** - Fast, customizable prompt with git integration
- **Zoxide** - Smart directory jumper (better than cd)

### Terminal & Editor
- **WezTerm** - GPU-accelerated terminal (Linux/macOS, uses Windows WezTerm for WSL2)
- **Neovim** - Extensible editor with mini.nvim for minimal, powerful setup
- **Tmux** - Terminal multiplexer with Catppuccin theme

### Development Tools
- **Git** - Version control with delta for beautiful diffs
- **Lazygit** - Terminal UI for git operations
- **GitHub CLI** - Manage GitHub from the command line

### Modern CLI Utilities
- **eza** - Modern ls replacement with icons
- **fd** - Modern find replacement
- **ripgrep** - Modern grep replacement
- **bat** - cat with syntax highlighting
- **fzf** - Fuzzy finder for files, history, and more
- **delta** - Beautiful git diffs

## 🛠️ Installation

### Prerequisites

- **Git** - For cloning this repository
- **Curl** - For installing Nix
- **Linux, macOS, or WSL2** - Tested on Ubuntu 22.04+, macOS 13+, WSL2

### Quick Install

```bash
# Clone the repository
git clone https://github.com/yourusername/dotfiles.git ~/dotfiles
cd ~/dotfiles

# Run the installer
./install.sh
```

The installer will:
1. Install Nix with flakes enabled
2. Install Home Manager
3. Build and activate your configuration
4. Set Fish as your default shell
5. Set up all tools and configurations

### Manual Installation

If you prefer more control:

```bash
# 1. Install Nix (if not already installed)
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

# 2. Enable flakes (if not already enabled)
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf

# 3. Clone dotfiles
git clone https://github.com/yourusername/dotfiles.git ~/dotfiles
cd ~/dotfiles

# 4. Build and activate (choose your platform)
# For Linux:
nix build .#homeConfigurations."user@linux".activationPackage
./result/activate

# For WSL2:
nix build .#homeConfigurations."user@wsl".activationPackage
./result/activate

# For macOS:
nix build .#homeConfigurations."user@darwin".activationPackage
./result/activate
```

## 📁 Project Structure

```
dotfiles/
├── flake.nix                   # Nix flake entry point
├── flake.lock                  # Locked dependencies
├── home.nix                    # Main Home Manager configuration
├── install.sh                  # Installation script
├── README.md                   # This file
│
├── modules/                    # Nix modules for each tool
│   ├── common.nix             # Common settings
│   ├── fish.nix               # Fish shell configuration
│   ├── wezterm.nix            # WezTerm terminal
│   ├── neovim.nix             # Neovim editor
│   ├── starship.nix           # Starship prompt
│   ├── git.nix                # Git configuration
│   └── tmux.nix               # Tmux multiplexer
│
├── config/                     # Application configs
│   └── wezterm/
│       └── wezterm.lua        # WezTerm config with OS detection
│
├── nvim/                       # Neovim configuration
│   ├── init.lua               # Main config
│   └── lua/                   # Lua modules
│       └── config/
│           ├── options.lua    # Editor options
│           ├── keymaps.lua    # Key mappings
│           ├── autocmds.lua   # Auto commands
│           └── plugins.lua    # Plugin configuration
│
└── .github/
    └── workflows/
        └── nix-check.yml      # CI workflow
```

## ⚙️ Configuration

### Platform-Specific Setup

The configuration automatically detects your platform and applies the correct settings:

- **Linux**: Full configuration with WezTerm
- **WSL2**: Configuration without WezTerm (uses Windows WezTerm)
- **macOS**: Full configuration with WezTerm

### Git Identity

Create `~/.config/git/config.local` to set your Git identity:

```ini
[user]
    name = Your Name
    email = your.email@example.com
```

### Customization

All configuration is in Nix files. To customize:

1. Edit the relevant module in `modules/`
2. Rebuild with `nix-rebuild` or `./install.sh --rebuild`

## 🔄 Updating

### Update All Packages

```bash
cd ~/dotfiles
./install.sh --update
```

Or use the convenience alias:

```bash
nix-update
```

### Rebuild Without Updating

```bash
cd ~/dotfiles
./install.sh --rebuild
```

Or:

```bash
nix-rebuild
```

### Rollback Changes

Nix allows you to rollback to previous configurations:

```bash
# List generations
home-manager generations

# Rollback to previous generation
home-manager generations | head -2 | tail -1 | awk '{print $7}' | xargs -I {} {}/activate
```

## 🎨 Theme

All tools use the **Catppuccin Mocha** color scheme for a consistent look:
- Dark, comfortable colors
- Excellent contrast
- Beautiful syntax highlighting

## ⌨️ Key Bindings

### Fish Shell

- `Ctrl+R` - Search command history with fzf
- `Ctrl+F` - Accept autosuggestion
- `Alt+F` - Accept one word from autosuggestion
- Vi mode enabled - press `Esc` for normal mode

### Neovim

- `<Space>` - Leader key
- `<Space>e` - File explorer
- `<Space>ff` - Find files
- `<Space>fg` - Live grep
- `<Space>fb` - Find buffers
- `<Space>w` - Save file

### Tmux

- `Ctrl+a` - Prefix key
- `Prefix |` - Split vertically
- `Prefix -` - Split horizontally
- `Prefix h/j/k/l` - Navigate panes
- `Prefix H/J/K/L` - Resize panes

### WezTerm

- `Ctrl+Shift+D` - Split horizontal
- `Ctrl+D` - Split vertical
- `Ctrl+Shift+H/J/K/L` - Navigate panes
- `Ctrl+Alt+H/J/K/L` - Resize panes
- `Ctrl+Shift+T` - New tab
- `Ctrl+Shift+W` - Close pane

## 🧪 CI/CD

GitHub Actions automatically:
- Validates Nix flake syntax
- Builds all platform configurations
- Checks code formatting
- Validates module structure
- Tests Fish and Neovim configs
- Runs security audits

## 🐛 Troubleshooting

### Nix installation fails

If the Determinate installer fails, try the official installer:

```bash
sh <(curl -L https://nixos.org/nix/install) --daemon
```

### Fish shell not default after installation

```bash
# Find fish path
which fish

# Add to /etc/shells if needed
echo $(which fish) | sudo tee -a /etc/shells

# Change shell
chsh -s $(which fish)

# Log out and back in
```

### Configuration build fails

```bash
# Check flake for errors
nix flake check

# Try building with more verbose output
nix build .#homeConfigurations."user@linux".activationPackage --print-build-logs --show-trace
```

### WezTerm config not loading

```bash
# Check if config is linked correctly
ls -la ~/.config/wezterm/

# Manually link if needed
ln -sf ~/dotfiles/config/wezterm/wezterm.lua ~/.config/wezterm/wezterm.lua
```

### Fonts not displaying correctly

Install a Nerd Font. With Nix:

```bash
# Add to home.nix packages:
pkgs.nerdfonts
```

Or manually install JetBrains Mono Nerd Font from [Nerd Fonts](https://www.nerdfonts.com/).

## 📚 Learning Resources

### Nix & Home Manager
- [Nix Pills](https://nixos.org/guides/nix-pills/) - Learn Nix fundamentals
- [Home Manager Manual](https://nix-community.github.io/home-manager/) - Official documentation
- [NixOS Wiki](https://nixos.wiki/) - Community knowledge base

### Tools
- [Fish Shell Documentation](https://fishshell.com/docs/current/)
- [Neovim Documentation](https://neovim.io/doc/)
- [WezTerm Documentation](https://wezfurlong.org/wezterm/)

## 🤝 Contributing

Contributions are welcome! Feel free to:
- Open issues for bugs or feature requests
- Submit pull requests with improvements
- Share your customizations

## 📝 License

This project is licensed under the MIT License.

## 🙏 Acknowledgments

- [NixOS](https://nixos.org/) - For the amazing package manager
- [Home Manager](https://github.com/nix-community/home-manager) - For user environment management
- [Catppuccin](https://github.com/catppuccin/catppuccin) - For the beautiful color scheme
- [mini.nvim](https://github.com/echasnovski/mini.nvim) - For the modular Neovim plugins
- All the open source tool maintainers

## 🔗 Related Projects

- [NixOS Dotfiles](https://github.com/topics/nixos-dotfiles) - Other Nix-based dotfiles
- [Awesome Nix](https://github.com/nix-community/awesome-nix) - Curated Nix resources

---

**Note**: This configuration replaces the previous bash-script-based setup with a fully declarative Nix-based approach for better reproducibility and cross-platform support.
