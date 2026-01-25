# Fish Shell Reference

Quick reference for Fish shell configuration, functions, and abbreviations.

## Vi Mode

Fish is configured with Vi keybindings. Mode indicators:
- 🅝 **NORMAL** - Navigate and edit
- 🅘 **INSERT** - Insert text
- 🅥 **VISUAL** - Visual selection
- 🅡 **REPLACE** - Replace mode

## Key Bindings

| Key | Mode | Description |
|-----|------|-------------|
| `Ctrl+O` | any | Open Yazi file manager (with directory change on exit) |

## Abbreviations

Abbreviations expand when you press Space or Enter.

### Directory Listing (eza)

| Abbr | Expands To | Description |
|------|------------|-------------|
| `ls` | `eza --icons --group-directories-first` | List files with icons |
| `ll` | `eza --icons --group-directories-first -l` | Long format |
| `la` | `eza --icons --group-directories-first -la` | Long format with hidden |
| `lt` | `eza --icons --group-directories-first --tree` | Tree view |

### Git

| Abbr | Expands To | Description |
|------|------------|-------------|
| `g` | `git` | Git shortcut |
| `gs` | `git status` | Show status |
| `ga` | `git add` | Stage files |
| `gc` | `git commit` | Commit |
| `gp` | `git push` | Push to remote |
| `gl` | `git pull` | Pull from remote |
| `gd` | `git diff` | Show diff |
| `gco` | `git checkout` | Checkout |
| `gb` | `git branch` | Branch operations |
| `glg` | `git log --graph --oneline --decorate` | Pretty log |

### Navigation

| Abbr | Expands To | Description |
|------|------------|-------------|
| `..` | `cd ..` | Go up one directory |
| `...` | `cd ../..` | Go up two directories |
| `....` | `cd ../../..` | Go up three directories |
| `dotfiles` | `cd ~/.config/dotfiles` | Go to dotfiles |
| `config` | `cd ~/.config` | Go to config |

### Nix / Home Manager

| Abbr | Expands To | Description |
|------|------------|-------------|
| `nix-rebuild` | `nix-manager rebuild` | Rebuild configuration |
| `nix-update` | `nix-manager update` | Update flake inputs |
| `nix-clean` | `nix-manager clean` | Clean old generations |

### Devbox

| Abbr | Expands To | Description |
|------|------------|-------------|
| `db` | `devbox` | Devbox shortcut |
| `dbs` | `devbox shell` | Enter devbox shell |
| `dbr` | `devbox run` | Run devbox command |
| `dba` | `devbox add` | Add package |
| `dbi` | `devbox init` | Initialize project |

### Editor

| Abbr | Expands To | Description |
|------|------------|-------------|
| `vi` | `nvim` | Open Neovim |
| `vim` | `nvim` | Open Neovim |

### Safety

| Abbr | Expands To | Description |
|------|------------|-------------|
| `rm` | `rm -i` | Remove with confirmation |
| `cp` | `cp -i` | Copy with confirmation |
| `mv` | `mv -i` | Move with confirmation |

## Custom Functions

### Git Functions

| Function | Description | Usage |
|----------|-------------|-------|
| `gcm` | Git commit with message | `gcm "commit message"` |
| `gac` | Git add all and commit | `gac "commit message"` |
| `gacp` | Git add all, commit and push | `gacp "commit message"` |
| `git-worktree-add` | Create git worktree with file copying | `git-worktree-add -b branch ../path` |
| `jj-workspace-add` | Create jj workspace with file copying | `jj-workspace-add ../path` |

### File/Directory Functions

| Function | Description | Usage |
|----------|-------------|-------|
| `mkcd` | Make directory and cd into it | `mkcd new-directory` |
| `extract` | Extract various archive formats | `extract file.tar.gz` |
| `f` | Quick file search with fzf | `f` |
| `fd_dir` | Quick directory search with fzf | `fd_dir` |

### Yazi (File Manager)

| Function | Description | Usage |
|----------|-------------|-------|
| `y` | Open Yazi file manager | `y` or `y /path` |
| `yazi-cd` | Open Yazi with directory change on exit | `yazi-cd` |

### Nix Functions

| Function | Description | Usage |
|----------|-------------|-------|
| `rebuild` | Rebuild home-manager configuration | `rebuild` |
| `nix-search` | Search for Nix packages | `nix-search package-name` |

## Plugins

### z (Directory Jumper)

Quickly jump to frequently visited directories.

```fish
z dotfiles     # Jump to most frequently used "dotfiles" directory
z nvim         # Jump to directory matching "nvim"
z -l           # List all tracked directories
```

### fzf.fish (Fuzzy Finder Integration)

| Key | Description |
|-----|-------------|
| `Ctrl+Alt+F` | Search files |
| `Ctrl+Alt+L` | Search git log |
| `Ctrl+Alt+S` | Search git status |
| `Ctrl+Alt+P` | Search processes |
| `Ctrl+R` | Search command history |
| `Ctrl+V` | Search environment variables |

## Supported Archive Formats

The `extract` function supports:
- `.tar.bz2`, `.tbz2` - tar with bzip2
- `.tar.gz`, `.tgz` - tar with gzip
- `.tar` - tar archive
- `.bz2` - bzip2
- `.gz` - gzip
- `.zip` - zip archive
- `.rar` - RAR archive
- `.7z` - 7zip archive
- `.Z` - compress

## Color Theme

Fish is configured with Catppuccin Mocha colors for a consistent look with Neovim and WezTerm.
