-- WezTerm configuration
local wezterm = require 'wezterm'
local config = {}

-- Use the config builder if available
if wezterm.config_builder then
  config = wezterm.config_builder()
end

-- Color scheme
config.color_scheme = 'Catppuccin Mocha'

-- Font configuration
config.font = wezterm.font_with_fallback {
  'JetBrains Mono',
  'FiraCode Nerd Font',
  'Noto Color Emoji',
}
config.font_size = 11.0
config.line_height = 1.2

-- Window configuration
config.window_decorations = "RESIZE"
config.window_background_opacity = 0.95
config.window_padding = {
  left = 10,
  right = 10,
  top = 10,
  bottom = 10,
}
config.enable_tab_bar = true
config.tab_bar_at_bottom = false
config.use_fancy_tab_bar = true
config.hide_tab_bar_if_only_one_tab = true

-- Cursor configuration
config.default_cursor_style = 'BlinkingBar'
config.cursor_blink_rate = 500
config.cursor_blink_ease_in = 'Constant'
config.cursor_blink_ease_out = 'Constant'

-- Scrollback
config.scrollback_lines = 10000

-- Key bindings
config.keys = {
  -- Split panes
  {
    key = 'd',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.SplitHorizontal { domain = 'CurrentPaneDomain' },
  },
  {
    key = 'd',
    mods = 'CTRL',
    action = wezterm.action.SplitVertical { domain = 'CurrentPaneDomain' },
  },
  -- Navigate panes
  {
    key = 'h',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.ActivatePaneDirection 'Left',
  },
  {
    key = 'l',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.ActivatePaneDirection 'Right',
  },
  {
    key = 'k',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.ActivatePaneDirection 'Up',
  },
  {
    key = 'j',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.ActivatePaneDirection 'Down',
  },
  -- Resize panes
  {
    key = 'h',
    mods = 'CTRL|ALT',
    action = wezterm.action.AdjustPaneSize { 'Left', 5 },
  },
  {
    key = 'l',
    mods = 'CTRL|ALT',
    action = wezterm.action.AdjustPaneSize { 'Right', 5 },
  },
  {
    key = 'k',
    mods = 'CTRL|ALT',
    action = wezterm.action.AdjustPaneSize { 'Up', 5 },
  },
  {
    key = 'j',
    mods = 'CTRL|ALT',
    action = wezterm.action.AdjustPaneSize { 'Down', 5 },
  },
  -- Close pane
  {
    key = 'w',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.CloseCurrentPane { confirm = true },
  },
  -- Copy/Paste
  {
    key = 'c',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.CopyTo 'Clipboard',
  },
  {
    key = 'v',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.PasteFrom 'Clipboard',
  },
  -- Search
  {
    key = 'f',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.Search { CaseSensitiveString = '' },
  },
  -- New tab
  {
    key = 't',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.SpawnTab 'CurrentPaneDomain',
  },
  -- Switch tabs
  {
    key = 'Tab',
    mods = 'CTRL',
    action = wezterm.action.ActivateTabRelative(1),
  },
  {
    key = 'Tab',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.ActivateTabRelative(-1),
  },
  -- Zoom pane
  {
    key = 'z',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.TogglePaneZoomState,
  },
  -- Show launcher
  {
    key = 'l',
    mods = 'CTRL|SHIFT|ALT',
    action = wezterm.action.ShowLauncher,
  },
  -- Reload configuration
  {
    key = 'r',
    mods = 'CTRL|SHIFT|ALT',
    action = wezterm.action.ReloadConfiguration,
  },
}

-- Mouse bindings
config.mouse_bindings = {
  -- Right click paste
  {
    event = { Up = { streak = 1, button = 'Right' } },
    mods = 'NONE',
    action = wezterm.action.PasteFrom 'Clipboard',
  },
  -- Change font size
  {
    event = { Down = { streak = 1, button = { WheelUp = 1 } } },
    mods = 'CTRL',
    action = wezterm.action.IncreaseFontSize,
  },
  {
    event = { Down = { streak = 1, button = { WheelDown = 1 } } },
    mods = 'CTRL',
    action = wezterm.action.DecreaseFontSize,
  },
}

-- Launch menu
config.launch_menu = {
  {
    label = 'Bash',
    args = { 'bash', '-l' },
  },
  {
    label = 'Zsh',
    args = { 'zsh', '-l' },
  },
  {
    label = 'Top',
    args = { 'top' },
  },
}

-- Performance
config.front_end = "OpenGL"
config.enable_wayland = true
config.max_fps = 120

-- Bell
config.audible_bell = "Disabled"
config.visual_bell = {
  fade_in_duration_ms = 75,
  fade_out_duration_ms = 75,
  target = 'CursorColor',
}

return config