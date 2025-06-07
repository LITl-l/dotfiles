# Tmux

Terminal multiplexer with Catppuccin theme and vim-style navigation.

## What it does

Tmux enables terminal session management with:
- **Multiple windows** and panes in a single session
- **Session persistence** across disconnects
- **Vim-style navigation** and keybindings
- **Plugin ecosystem** for extended functionality
- **Beautiful Catppuccin theme** for consistent aesthetics

## Installation

Run the installation script:

```bash
./tmux/install.sh
```

## Key configuration

### Prefix key
- **Changed from Ctrl-b to Ctrl-a** for easier access
- **Double prefix**: `Ctrl-a Ctrl-a` sends literal Ctrl-a

### Window and pane management

**Splitting panes:**
- **`|`**: Split horizontally (side by side)
- **`-`**: Split vertically (top/bottom)

**Navigation (vim-style):**
- **`h j k l`**: Move between panes
- **`Ctrl-h Ctrl-l`**: Previous/next window
- **`Tab`**: Last window

**Resizing:**
- **`H J K L`**: Resize panes (repeatable)
- **`m`**: Maximize/restore pane

### Copy mode
- **Vi-mode enabled**: `v` to select, `y` to copy
- **Rectangle selection**: `Ctrl-v`
- **Mouse support**: Click and drag to select

## Theme and appearance

### Catppuccin colors
- **Status bar**: Top position with beautiful gradients
- **Active indicators**: Blue highlights for current items
- **Pane borders**: Subtle inactive, bright active
- **Window status**: Clear current/inactive distinction

### Status bar elements
- **Left**: Session name with icon
- **Right**: Date, time, and hostname
- **Windows**: Index, name, and zoom indicator

## Plugin ecosystem

### TPM (Tmux Plugin Manager)
- **Auto-installation**: Installs on first run
- **Plugin management**: Install/update/remove plugins

### Included plugins
- **tmux-sensible**: Sensible default settings
- **tmux-yank**: Enhanced copy/paste
- **tmux-resurrect**: Save/restore sessions
- **tmux-continuum**: Automatic session saving
- **vim-tmux-navigator**: Seamless vim/tmux navigation

### Plugin settings
- **Auto-restore**: Sessions restore on startup
- **Save interval**: 10 minutes
- **Content capture**: Pane contents included in saves

## Key bindings reference

### Basic operations
- **`Ctrl-a r`**: Reload configuration
- **`Ctrl-a ?`**: Show help/key bindings
- **`Ctrl-a d`**: Detach session

### Window management
- **`Ctrl-a c`**: New window
- **`Ctrl-a w`**: List windows
- **`Ctrl-a ,`**: Rename window
- **`Ctrl-a &`**: Kill window

### Session management
- **`Ctrl-a s`**: List sessions
- **`Ctrl-a $`**: Rename session
- **`Ctrl-a (`**: Previous session
- **`Ctrl-a )`**: Next session

## Performance optimizations

- **256 color support**: Full color terminal
- **True color**: 24-bit color support
- **Fast escape**: No delay for escape sequences
- **Large history**: 50,000 lines scrollback
- **Aggressive resize**: Better multi-client support

## Integration features

### Vim/Neovim
- **Seamless navigation**: Move between vim splits and tmux panes
- **Copy mode**: Vim-style text selection
- **Terminal integration**: Proper color and cursor support

### Mouse support
- **Full mouse integration**: Click, scroll, resize
- **Copy/paste**: Mouse selection works naturally
- **Pane switching**: Click to focus panes