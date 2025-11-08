# WezTerm

GPU-accelerated terminal emulator with advanced features and Catppuccin theme.

> **Managed by Nix**: This configuration is automatically managed by the main Nix flakes setup. See [modules/wezterm.nix](../modules/wezterm.nix) for the Nix configuration. No manual installation required when using the main dotfiles setup.
>
> **Note**: WezTerm is disabled on WSL2 configurations as most users prefer using Windows Terminal or Windows WezTerm.

## What it does

WezTerm provides a modern terminal experience with:
- **GPU acceleration** for smooth performance
- **True color support** with rich themes
- **Advanced text rendering** with font fallbacks
- **Built-in multiplexing** like tmux
- **Extensive customization** via Lua configuration
- **Cross-platform** with OS-specific settings

## Installation

### Via Nix (Recommended)

WezTerm is automatically installed and configured when you use the main dotfiles setup:

```bash
# See main README for full installation
home-manager switch --flake ~/dotfiles
```

The Lua configuration file ([config/wezterm/wezterm.lua](../config/wezterm/wezterm.lua)) includes OS detection for platform-specific settings.

### Standalone (Legacy)

If you need just wezterm configuration without the full Nix setup:

```bash
./wezterm/install.sh
```

## Key features

### Visual enhancements
- **Catppuccin Mocha theme** for consistent aesthetics
- **JetBrains Mono font** with Nerd Font fallback
- **Background opacity**: 95% for subtle transparency
- **Blinking cursor**: Smooth bar cursor animation
- **Fancy tab bar**: Beautiful tab styling

### Window management
- **Split panes**: Horizontal and vertical splitting
- **Tab support**: Multiple tabs per window
- **Pane navigation**: Vim-style movement
- **Zoom functionality**: Focus single pane
- **Resize support**: Adjust pane sizes

### Performance
- **OpenGL frontend**: Hardware acceleration
- **120 FPS**: Smooth animations and scrolling
- **Wayland support**: Native Linux integration
- **Large scrollback**: 10,000 lines of history

## Key bindings

### Pane management
- **`Ctrl+Shift+d`**: Split horizontally (side by side)
- **`Ctrl+d`**: Split vertically (top/bottom)
- **`Ctrl+Shift+w`**: Close current pane (with confirmation)
- **`Ctrl+Shift+z`**: Toggle pane zoom

### Navigation
- **`Ctrl+Shift+h/j/k/l`**: Navigate between panes
- **`Ctrl+Alt+h/j/k/l`**: Resize panes
- **`Ctrl+Tab`**: Next tab
- **`Ctrl+Shift+Tab`**: Previous tab

### Utility functions
- **`Ctrl+Shift+c`**: Copy to clipboard
- **`Ctrl+Shift+v`**: Paste from clipboard
- **`Ctrl+Shift+f`**: Search in terminal
- **`Ctrl+Shift+t`**: New tab
- **`Ctrl+Shift+Alt+l`**: Show launcher menu

### Special features
- **`Ctrl+Shift+Alt+r`**: Reload configuration
- **Right click**: Paste from clipboard
- **Ctrl+Scroll**: Increase/decrease font size

## Configuration highlights

### Font setup
```lua
config.font = wezterm.font_with_fallback {
  'JetBrains Mono',      -- Primary programming font
  'FiraCode Nerd Font',  -- Nerd Font icons
  'Noto Color Emoji',    -- Emoji support
}
```

### Visual settings
- **11pt font size**: Comfortable reading
- **1.2 line height**: Better spacing
- **10px padding**: Comfortable margins
- **Fancy tab bar**: At top with auto-hide

### Launch menu
Quick access to different shells:
- **Bash**: Login shell
- **Zsh**: Default shell
- **Top**: System monitor

## Mouse features

### Enhanced interactions
- **Right click paste**: Quick clipboard access
- **Scroll wheel**: Natural scrolling
- **Ctrl+scroll**: Font size adjustment
- **Click navigation**: Select panes and tabs

### Selection
- **Click and drag**: Text selection
- **Double click**: Word selection
- **Triple click**: Line selection
- **Automatic copy**: Selected text copies to clipboard

## Integration benefits

### Development workflow
- **Multiple terminals**: Side-by-side development
- **Session persistence**: Tabs survive restarts
- **Fast switching**: Keyboard-driven navigation
- **Search functionality**: Find in terminal output

### System integration
- **Clipboard sync**: Seamless copy/paste
- **URL handling**: Click to open links
- **File associations**: Proper MIME type handling
- **Window management**: Integrates with desktop environment