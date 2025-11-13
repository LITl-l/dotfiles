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
- **Worktrees**: Full worktree management with auto-cd

### Worktree operations
- **List worktrees**: `W` - View all worktrees
- **Worktree info**: `Ctrl+w i` - Show worktrees and current location
- **Add worktree**: `Ctrl+w a` - Create new worktree with prompts
- **New branch in worktree**: `Ctrl+w n` - Create branch in worktree (with auto-cd and branch prefix selection)
- **Go to worktree**: `Ctrl+w g` - Navigate to worktree for selected branch (opens new shell)
- **Smart checkout**: `Ctrl+w c` - Checkout branch (auto-cd to worktree if it exists, opens lazygit)
- **Remove worktree**: `Ctrl+w r` - Delete a worktree
- **Move worktree**: `Ctrl+w m` - Move worktree to new location
- **Prune worktrees**: `Ctrl+w p` - Clean up stale worktree data

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

## Worktree workflow

Git worktrees allow you to have multiple working directories from a single repository, making it easy to work on multiple branches simultaneously without stashing or switching contexts.

### Quick start with worktrees

1. **Create a new feature in a worktree**:
   - Press `Ctrl+w n` in lazygit
   - Select branch prefix (feature/, fix/, etc.)
   - Enter branch name
   - Lazygit will create the worktree and automatically navigate to it

2. **Switch to an existing worktree branch**:
   - Navigate to the branches panel
   - Select a branch that exists in a worktree
   - Press `Ctrl+w c` to checkout with auto-cd
   - Lazygit will automatically switch to that worktree directory

3. **View all worktrees**:
   - Press `W` to see a list of all worktrees
   - Press `Ctrl+w i` for detailed worktree information

### Worktree best practices

- **Naming convention**: Worktrees are created in `../<branch-name>` by default
- **Branch prefixes**: Use standard prefixes (feature/, fix/, etc.) for organization
- **Cleanup**: Use `Ctrl+w r` to remove worktrees when done
- **Pruning**: Run `Ctrl+w p` periodically to clean up stale worktree data

### Auto-cd behavior

The configuration includes smart auto-cd behavior:
- **`Ctrl+w c`**: When checking out a branch in a worktree, automatically cd to that worktree and reopen lazygit
- **`Ctrl+w g`**: Navigate to a worktree and open a new shell there
- **`Ctrl+w n`**: Create a new worktree and immediately switch to it with lazygit

This eliminates the need to manually navigate between worktree directories and ensures you're always working in the correct context.

## Dependencies

- **Git**: Version control system
- **Delta**: Enhanced diff viewer
- **Nvim**: Text editor integration