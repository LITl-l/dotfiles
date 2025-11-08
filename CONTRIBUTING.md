# Contributing to Dotfiles

Thank you for your interest in contributing to this dotfiles repository! This guide will help you understand the development workflow and best practices.

## 📋 Table of Contents

- [Development Setup](#development-setup)
- [Making Changes](#making-changes)
- [Testing Changes](#testing-changes)
- [Code Style](#code-style)
- [Pull Request Process](#pull-request-process)
- [Project Structure](#project-structure)

## 🚀 Development Setup

### Prerequisites

- **Nix** with flakes enabled
- **Git** for version control
- **Basic understanding** of Nix language (helpful but not required)

### Clone and Setup

```bash
# Clone the repository
git clone https://github.com/yourusername/dotfiles.git
cd dotfiles

# Enter development shell (optional, provides extra tools)
nix develop

# Test build the configuration for your platform
nix build .#homeConfigurations."user@linux".activationPackage
```

## 🛠️ Making Changes

### Configuration Files

The repository is organized as follows:

- **`flake.nix`**: Entry point defining all configurations
- **`home.nix`**: Main Home Manager configuration
- **`modules/*.nix`**: Individual tool configurations
- **`config/`**: Application-specific config files (Lua, TOML, etc.)
- **`nvim/`**: Neovim configuration files

### Common Modifications

#### Adding a New Package

Edit `home.nix` and add to the `home.packages` list:

```nix
home.packages = with pkgs; [
  # ... existing packages
  your-new-package
];
```

#### Creating a New Module

1. Create a new file in `modules/`, e.g., `modules/alacritty.nix`
2. Add your configuration:

```nix
{ config, pkgs, lib, ... }:

{
  programs.alacritty = {
    enable = true;
    settings = {
      # Your configuration here
    };
  };
}
```

3. Import it in `home.nix`:

```nix
imports = [
  # ... existing imports
  ./modules/alacritty.nix
];
```

#### Modifying Existing Configuration

Simply edit the relevant module file in `modules/` and rebuild.

## 🧪 Testing Changes

### Local Testing

Before committing, always test your changes:

```bash
# Check flake for errors
nix flake check

# Build without activating
nix build .#homeConfigurations."user@linux".activationPackage

# Activate changes (backs up old configuration)
./result/activate

# Or use home-manager directly
home-manager switch --flake .
```

### Testing on Multiple Platforms

If you have access to multiple platforms, test your changes on:

- Linux (`user@linux`)
- WSL2 (`user@wsl`)
- NixOS on WSL2 (`nixos@wsl`)
- macOS (`user@darwin`)

```bash
# Build for specific platform
nix build .#homeConfigurations."user@darwin".activationPackage
```

### Rollback if Needed

If something breaks, Home Manager allows easy rollback:

```bash
# List generations
home-manager generations

# Activate previous generation
/nix/store/<hash>-home-manager-generation/activate
```

## 📐 Code Style

### Nix Code Formatting

Use `nixpkgs-fmt` to format Nix files:

```bash
# Format all Nix files
nixpkgs-fmt **/*.nix

# Or format specific file
nixpkgs-fmt modules/fish.nix
```

### Nix Style Guidelines

- **Indentation**: 2 spaces
- **Line length**: Try to keep under 100 characters
- **Comments**: Use `#` for comments, explain complex logic
- **Attribute ordering**: Group related attributes together

Example:

```nix
{ config, pkgs, lib, ... }:

{
  programs.fish = {
    enable = true;

    # Shell initialization
    shellInit = ''
      # Disable greeting
      set -g fish_greeting
    '';

    # Custom functions
    functions = {
      hello = {
        description = "Greet the user";
        body = ''
          echo "Hello, $USER!"
        '';
      };
    };
  };
}
```

### Commit Messages

Follow conventional commit format with gitmoji:

```
:sparkles: feat(fish): add new fish function for git shortcuts
:bug: fix(neovim): resolve LSP startup error
:recycle: refactor(modules): reorganize module structure
:memo: docs(readme): update installation instructions
```

Common prefixes:
- `:sparkles:` `feat` - New features
- `:bug:` `fix` - Bug fixes
- `:recycle:` `refactor` - Code refactoring
- `:memo:` `docs` - Documentation
- `:white_check_mark:` `test` - Tests
- `:art:` `style` - Code style changes
- `:wrench:` `chore` - Maintenance tasks

## 🔀 Pull Request Process

### Before Submitting

1. **Test locally**: Ensure changes work on your system
2. **Format code**: Run `nixpkgs-fmt` on modified files
3. **Update docs**: Update README or module docs if needed
4. **Check CI**: Ensure `nix flake check` passes

### Submitting PR

1. **Fork the repository** (if you don't have write access)
2. **Create a feature branch**:
   ```bash
   git checkout -b feat/my-new-feature
   ```
3. **Make your changes** and commit with clear messages
4. **Push to your fork**:
   ```bash
   git push origin feat/my-new-feature
   ```
5. **Open a Pull Request** on GitHub

### PR Description Template

```markdown
## Description
Brief description of what this PR does.

## Type of Change
- [ ] New feature
- [ ] Bug fix
- [ ] Documentation update
- [ ] Refactoring
- [ ] Other (please describe)

## Testing
- [ ] Tested on Linux
- [ ] Tested on macOS
- [ ] Tested on WSL2
- [ ] Tested on NixOS

## Checklist
- [ ] Code formatted with nixpkgs-fmt
- [ ] Documentation updated
- [ ] `nix flake check` passes
- [ ] Commit messages follow conventional format
```

## 🏗️ Project Structure

### Key Files

```
dotfiles/
├── flake.nix              # Flake definition with configurations
├── home.nix               # Main Home Manager config
├── modules/               # Tool-specific Nix modules
│   ├── common.nix        # Common settings
│   ├── fish.nix          # Fish shell
│   ├── neovim.nix        # Neovim
│   ├── git.nix           # Git + Delta + Lazygit
│   ├── tmux.nix          # Tmux
│   ├── starship.nix      # Starship prompt
│   └── wezterm.nix       # WezTerm terminal
├── config/               # Non-Nix config files
│   └── wezterm/         # WezTerm Lua config
└── nvim/                # Neovim Lua config
    ├── init.lua
    └── lua/config/
```

### Module Pattern

Each module follows this pattern:

```nix
{ config, pkgs, lib, ... }:

{
  # Program configuration
  programs.tool = {
    enable = true;
    # ... settings
  };

  # Optional: XDG config files
  xdg.configFile."tool/config".source = ./config/tool/config;

  # Optional: Environment variables
  home.sessionVariables = {
    TOOL_VAR = "value";
  };
}
```

## 🐛 Reporting Issues

When reporting issues, please include:

- **Platform**: Linux/macOS/WSL2/NixOS
- **Nix version**: `nix --version`
- **Error message**: Full error output
- **Steps to reproduce**: How to trigger the issue
- **Expected behavior**: What should happen
- **Actual behavior**: What actually happens

## 📚 Resources

- [Home Manager Manual](https://nix-community.github.io/home-manager/)
- [Nix Pills](https://nixos.org/guides/nix-pills/)
- [NixOS Wiki](https://nixos.wiki/)
- [Nix Package Search](https://search.nixos.org/)

## 💬 Questions?

Feel free to:
- Open an issue for questions
- Start a discussion on GitHub
- Check existing issues and discussions

---

Thank you for contributing! 🎉
