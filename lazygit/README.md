# Lazygit

Terminal-based Git UI with Catppuccin theme and vim-style keybindings.

> **Managed by Nix**: This configuration is automatically managed by the main Nix flakes setup. See [modules/git.nix](../modules/git.nix) for the Nix configuration (lazygit config is included there). No manual installation required when using the main dotfiles setup.

## What it does

Lazygit provides a beautiful, interactive Git interface featuring:
- **Visual Git operations** through an intuitive TUI
- **Vim-style navigation** and keybindings
- **Catppuccin theme** for consistent aesthetics
- **Delta integration** for enhanced diffs
- **Neovim integration** for editing
- **File tree view** for better organization

## Installation

### Via Nix (Recommended)

Lazygit is automatically installed and configured when you use the main dotfiles setup:

```bash
# See main README for full installation
home-manager switch --flake ~/dotfiles
```

### Standalone (Legacy)

If you need just lazygit configuration without the full Nix setup:

```bash
./lazygit/install.sh
```

## Key features

### Theme and appearance
- **Catppuccin colors** throughout the interface
- **Delta pager** integration for beautiful diffs
- **File tree view** for better navigation
- **Icons support** for visual clarity
- **Responsive layout** with configurable panels

### Navigation (Vim-style)
- **hjkl**: Navigate between panels and items
- **tab**: Switch between panels
- **space**: Select items
- **enter**: Open/execute actions
- **q**: Quit

### Git operations
- **Stage/unstage**: `a` (all), `space` (individual)
- **Commit**: `c` (normal), `C` (with editor), `A` (amend)
- **Push/pull**: `P` (push), `p` (pull)
- **Branch**: Create, checkout, merge, rebase
- **Stash**: Save, apply, pop stashes
- **Cherry-pick**: Copy commits between branches

### Basic operations
- **Stage/unstage**: `space` for individual files, `a` for all
- **Commit**: `c` for commit, `C` for amend
- **Push/pull**: `P` for push, `p` for pull
- **Branch management**: Create, checkout, delete branches
- **Stash**: Save and restore working changes
- **Merge/rebase**: Interactive git operations

## Configuration highlights

### Git integration
- **Auto-fetch**: Enabled for up-to-date status
- **Auto-refresh**: Real-time updates
- **Delta pager**: Enhanced diff viewing
- **Topo-order**: Logical commit ordering

### UI preferences
- **No random tips**: Cleaner interface
- **Command log**: Track recent operations
- **Mouse support**: Click interactions
- **Commit length**: Visual feedback

### Editor integration
- **Nvim preset**: Configured for Neovim
- **Line jumping**: Open files at specific lines
- **External links**: Browser integration

## Usage tips

1. **Start lazygit** in any Git repository
2. **Use `?`** to see help menu and keybindings
3. **Tab through panels**: Files, branches, commits, stash
4. **Space to select**, **enter to execute**
5. **`x` for options menu** on any item

## Dependencies

- **Git**: Version control system
- **Delta**: Enhanced diff viewer
- **Nvim**: Text editor integration