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
- **Fish** - Modern shell with vi mode, Catppuccin colors, and excellent autosuggestions
  - **z** plugin - Directory jumper for quick navigation
  - **fzf.fish** plugin - Enhanced fuzzy finding integration
  - Custom functions for git, file search, and Nix shortcuts
- **Starship** - Fast, customizable prompt with git integration and language detection
- **Zoxide** - Smart directory jumper with frecency algorithm (better than cd)
- **Direnv** - Per-directory environment variables with Nix integration

### Terminal & Editor
- **WezTerm** - GPU-accelerated terminal (Linux/macOS, uses Windows WezTerm for WSL2)
- **Neovim** - Extensible editor with mini.nvim for minimal, powerful setup
- **Tmux** - Terminal multiplexer with Catppuccin theme

### Development Tools
- **Git** - Version control with delta for beautiful diffs
- **Lazygit** - Terminal UI for git operations
- **GitHub CLI** - Manage GitHub from the command line

### Modern CLI Utilities
- **eza** - Modern ls replacement with icons and git integration
- **fd** - Modern find replacement (fast, user-friendly)
- **ripgrep** - Modern grep replacement (recursive, fast)
- **bat** - cat with syntax highlighting and line numbers
- **fzf** - Fuzzy finder for files, history, and more
- **delta** - Beautiful git diffs with syntax highlighting
- **jq** / **yq-go** - JSON and YAML processors
- **htop** - Interactive process viewer
- **tree** - Directory tree visualizer

### Nix Development Tools
- **nixpkgs-fmt** - Nix code formatter
- **nil** - Nix Language Server for IDE integration
- **home-manager** - Declarative user environment manager
- Development shell with additional tools available via `nix develop`

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
├── install.sh                  # Nix-based installation script
├── install-legacy.sh           # Legacy bash-based installer (deprecated)
├── README.md                   # This file
├── CLAUDE.md                   # Claude Code instructions
│
├── modules/                    # Nix modules for each tool
│   ├── common.nix             # Common settings (SSH, GPG, readline)
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
│   ├── README.md              # Neovim-specific documentation
│   └── lua/config/            # Lua modules
│       ├── options.lua        # Editor options
│       ├── keymaps.lua        # Key mappings
│       ├── autocmds.lua       # Auto commands
│       ├── plugins.lua        # Plugin configuration
│       └── util.lua           # Utility functions
│
├── wezterm/                    # WezTerm documentation
│   └── README.md
│
├── git/                        # Git documentation
│   └── README.md
│
├── tmux/                       # Tmux documentation
│   └── README.md
│
├── starship/                   # Starship documentation
│   └── README.md
│
├── lazygit/                    # Lazygit documentation
│   └── README.md
│
├── Legacy tools/               # Deprecated bash-based configs
│   ├── zsh/                   # (Use Fish via Nix instead)
│   ├── sheldon/               # (Use Fish plugins via Nix instead)
│   ├── homebrew/              # (Use Nix packages instead)
│   ├── docker/                # (Standalone tool, not managed by Nix)
│   ├── proto/                 # (Standalone tool, not managed by Nix)
│   └── eza/                   # (Use eza via Nix packages instead)
│
└── .github/
    └── workflows/
        └── nix-check.yml      # CI workflow
```

## ⚙️ Configuration

> **Note**: This repository includes legacy bash-based installation scripts in individual tool directories (zsh/, docker/, etc.). These are **deprecated** and maintained only for reference. The modern, recommended approach is using the Nix flakes configuration described in this document.

### Platform-Specific Setup

The configuration automatically detects your platform and applies the correct settings:

- **Linux (Generic)**: Full configuration with WezTerm - use `user@linux`
- **WSL2**: Configuration without WezTerm (uses Windows WezTerm) - use `user@wsl`
- **NixOS on WSL2**: Optimized for NixOS on WSL2 - use `nixos@wsl`
- **macOS (Apple Silicon)**: Full configuration with WezTerm - use `user@darwin`

#### NixOS Configuration

If you're running NixOS (including NixOS-WSL), use the `nixos@wsl` configuration:

```bash
# Clone the repository
git clone https://github.com/yourusername/dotfiles.git ~/dotfiles
cd ~/dotfiles

# Build and activate for NixOS on WSL2
nix build .#homeConfigurations."nixos@wsl".activationPackage
./result/activate

# Or use home-manager directly
home-manager switch --flake .#nixos@wsl
```

This configuration:
- Sets the username to `nixos` (default NixOS-WSL user)
- Sets home directory to `/home/nixos`
- Disables WezTerm (uses Windows terminal)
- Enables all other tools and configurations

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

**Vi Mode Navigation:**
- Press `Esc` - Enter normal mode
- Visual mode indicators: 🅝 NORMAL, 🅘 INSERT, 🅥 VISUAL, 🅡 REPLACE
- Cursor changes by mode (block/line/underscore)

**Built-in Keybindings:**
- `Ctrl+R` - Search command history with fzf
- `Ctrl+F` - Accept autosuggestion
- `Alt+F` - Accept one word from autosuggestion
- `Alt+E` - Edit command in $EDITOR

**Custom Functions:**
- `f` - Interactive file search with preview (fd + fzf + bat)
- `fd_dir` - Interactive directory search and cd (fd + fzf + eza)
- `mkcd <dir>` - Create directory and cd into it
- `extract <file>` - Extract any archive format
- `rebuild` - Rebuild home-manager configuration
- `nix-search <pkg>` - Search for Nix packages

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

## 🔧 Advanced Usage

### Using the Development Shell

The repository includes a Nix development shell with additional tools:

```bash
cd ~/dotfiles
nix develop

# Now you have access to:
# - nixpkgs-fmt (format Nix files)
# - nil (Nix LSP)
# - home-manager CLI
```

### Testing Configuration Changes

Before activating changes system-wide, you can test build them:

```bash
# Test build for your platform
nix build .#homeConfigurations."user@linux".activationPackage

# Check flake for errors
nix flake check

# Format Nix files
nixpkgs-fmt **/*.nix
```

### Legacy Installation (Deprecated)

⚠️ **Not Recommended**: The repository contains legacy bash-based installation scripts (`install-legacy.sh` and tool-specific `install.sh` scripts). These are maintained for reference only and are no longer the recommended installation method.

The legacy approach:
- Used bash scripts to manually install tools
- Required manual configuration of dotfiles
- Didn't provide reproducibility guarantees
- Used Homebrew on macOS, manual installs on Linux

**Migration**: If you're using the legacy setup, consider migrating to the Nix-based approach for better reproducibility and cross-platform consistency.

## 📚 Learning Resources

### Nix & Home Manager
- [Nix Pills](https://nixos.org/guides/nix-pills/) - Learn Nix fundamentals
- [Home Manager Manual](https://nix-community.github.io/home-manager/) - Official documentation
- [NixOS Wiki](https://nixos.wiki/) - Community knowledge base
- [Nix Flakes Guide](https://nixos.wiki/wiki/Flakes) - Understanding flakes

### Tools
- [Fish Shell Documentation](https://fishshell.com/docs/current/)
- [Neovim Documentation](https://neovim.io/doc/)
- [WezTerm Documentation](https://wezfurlong.org/wezterm/)
- [Starship Documentation](https://starship.rs/)
- [Tmux Documentation](https://github.com/tmux/tmux/wiki)

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
