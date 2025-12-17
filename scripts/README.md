# Workspace Files Copy Feature

This feature automatically copies specified files when creating new Git worktrees or Jujutsu workspaces.

## Overview

When working with multiple worktrees or workspaces, you often need the same local configuration files (like `.env`, `.vscode/settings.json`, etc.) in each workspace. This feature automates the copying of these files.

## How It Works

### For Git Worktrees

**Automatic (via Git Hook):**
- When you create a new worktree with `git worktree add`, the `post-checkout` hook automatically copies configured files
- No additional commands needed

**Manual (via Fish Function):**
```fish
git-worktree-add <branch-name> <path>
```

### For Jujutsu Workspaces

**Via Fish Function:**
```fish
jj-workspace-add <path>
```

## Configuration

### Setup

Create a `.config-workspace-files` file in your repository root (or use the global config at `~/.config/workspace/files.conf`):

```bash
# Example .config-workspace-files
.env
.env.local
.vscode/settings.json
.idea/workspace.xml
```

- One file path per line (relative to repository root)
- Lines starting with `#` are ignored
- Empty lines are ignored

### Configuration Priority

The script looks for configuration files in this order:
1. `<repo-root>/.config-workspace-files` (repository-specific)
2. `~/.config/workspace/files.conf` (global)
3. `<repo-root>/.config-workspace-files.example` (example template)

### Example Template

An example configuration file is included at `.config-workspace-files.example`. Copy it to `.config-workspace-files` to get started:

```bash
cp .config-workspace-files.example .config-workspace-files
```

Edit the file to specify which files you want copied to new workspaces.

## Usage Examples

### Git Worktree

```fish
# Automatic copy (via hook)
git worktree add -b feature/new-feature ../new-feature

# Manual copy (via Fish function)
git-worktree-add -b feature/new-feature ../new-feature
```

### Jujutsu Workspace

```fish
# Create workspace and copy files
jj-workspace-add ../new-workspace
```

## Files

- `scripts/copy-workspace-files.sh` - Main copy script
- `git/hooks/post-checkout` - Git hook for automatic copying
- `.config-workspace-files.example` - Example configuration template
- `modules/fish.nix` - Fish function definitions

## Technical Details

### Git Hook

The `post-checkout` hook runs automatically after:
- `git worktree add`
- `git checkout` (when switching branches in a worktree)

The hook detects if it's running in a worktree context and only copies files during worktree creation.

### Fish Functions

- `git-worktree-add`: Wraps `git worktree add` and copies files
- `jj-workspace-add`: Wraps `jj workspace add` and copies files

Both functions:
1. Create the workspace
2. Find the copy script in the repository
3. Execute the script with source and destination paths
4. Report which files were copied

## Troubleshooting

### Files not being copied

1. Check that the configuration file exists and has the correct format
2. Verify that the source files exist in the main repository
3. Check that the copy script is executable: `ls -l scripts/copy-workspace-files.sh`
4. For Git: Verify hooks are configured: `git config core.hooksPath`

### Hook not running

After updating your Nix configuration:
```fish
home-manager switch --flake ~/dotfiles
```

This will:
- Copy the hook to `~/.config/git/hooks/post-checkout`
- Configure Git to use the hooks directory

## Notes

- The feature is optional - if no configuration file exists, workspaces are created normally
- Files are copied with preserved permissions (`cp -p`)
- If a file doesn't exist in the source, it's skipped with a warning
- The script creates destination directories as needed
