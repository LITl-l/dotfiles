-- WezTerm configuration with cross-platform support
local wezterm = require 'wezterm'
local config = {}

-- Use the config builder if available
if wezterm.config_builder then
  config = wezterm.config_builder()
end

-- OS detection
local is_windows = wezterm.target_triple:find("windows") ~= nil
local is_linux = wezterm.target_triple:find("linux") ~= nil
local is_macos = wezterm.target_triple:find("darwin") ~= nil

-- Color scheme
config.color_scheme = 'Catppuccin Mocha'

-- Font configuration
config.font = wezterm.font_with_fallback {
  'JetBrains Mono',
  'FiraCode Nerd Font',
  'Noto Color Emoji',
}

-- Platform-specific font sizes
if is_windows then
  config.font_size = 11.0
elseif is_macos then
  config.font_size = 13.0
else -- Linux
  config.font_size = 11.0
end

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

-- Default shell configuration (platform-specific)
if is_windows then
  -- On Windows, prefer WSL2 if available
  config.default_prog = { 'wsl.exe', '~' }
elseif is_linux then
  -- On Linux/NixOS, use fish shell from home-manager or system profile
  local fish_paths = {
    os.getenv('HOME') .. '/.nix-profile/bin/fish',  -- home-manager
    '/run/current-system/sw/bin/fish',              -- NixOS system-wide
    '/usr/bin/fish',                                -- fallback
  }

  -- Find the first valid fish binary
  local fish_bin = 'fish'  -- default fallback
  for _, path in ipairs(fish_paths) do
    local f = io.open(path, 'r')
    if f ~= nil then
      f:close()
      fish_bin = path
      break
    end
  end

  config.default_prog = { fish_bin, '-l' }
elseif is_macos then
  -- On macOS, use fish shell
  config.default_prog = { '/run/current-system/sw/bin/fish', '-l' }
end

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
  -- Copy/Paste (platform-specific)
  {
    key = 'c',
    mods = is_macos and 'CMD' or 'CTRL|SHIFT',
    action = wezterm.action.CopyTo 'Clipboard',
  },
  {
    key = 'v',
    mods = is_macos and 'CMD' or 'CTRL|SHIFT',
    action = wezterm.action.PasteFrom 'Clipboard',
  },
  -- Search
  {
    key = 'f',
    mods = is_macos and 'CMD' or 'CTRL|SHIFT',
    action = wezterm.action.Search { CaseSensitiveString = '' },
  },
  -- New tab
  {
    key = 't',
    mods = is_macos and 'CMD' or 'CTRL|SHIFT',
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
    mods = is_macos and 'CMD' or 'CTRL|SHIFT',
    action = wezterm.action.TogglePaneZoomState,
  },
  -- Show launcher
  {
    key = 'l',
    mods = is_macos and 'CMD|SHIFT' or 'CTRL|SHIFT|ALT',
    action = wezterm.action.ShowLauncher,
  },
  -- Reload configuration
  {
    key = 'r',
    mods = is_macos and 'CMD|SHIFT' or 'CTRL|SHIFT|ALT',
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

-- Launch menu (platform-specific)
config.launch_menu = {}

if is_windows then
  table.insert(config.launch_menu, {
    label = 'PowerShell',
    args = { 'powershell.exe', '-NoLogo' },
  })
  table.insert(config.launch_menu, {
    label = 'WSL2',
    args = { 'wsl.exe', '~' },
  })
  table.insert(config.launch_menu, {
    label = 'CMD',
    args = { 'cmd.exe' },
  })
else
  table.insert(config.launch_menu, {
    label = 'Fish',
    args = { 'fish', '-l' },
  })
  table.insert(config.launch_menu, {
    label = 'Bash',
    args = { 'bash', '-l' },
  })
  table.insert(config.launch_menu, {
    label = 'Top',
    args = { 'top' },
  })
end

-- Performance
config.front_end = "OpenGL"
config.max_fps = 120

-- Platform-specific settings
if is_linux then
  config.enable_wayland = true
end

-- Bell
config.audible_bell = "Disabled"
config.visual_bell = {
  fade_in_duration_ms = 75,
  fade_out_duration_ms = 75,
  target = 'CursorColor',
}

-- WSL-specific configuration
if is_windows then
  -- Better font rendering on Windows
  config.front_end = "WebGpu"
  config.webgpu_power_preference = "HighPerformance"
end

return config
