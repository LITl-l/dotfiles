-- Keyboard shortcuts configuration
local wezterm = require 'wezterm'
local platform = require 'platform'

local M = {}

function M.apply(config)
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
      mods = platform.is_macos and 'CMD' or 'CTRL|SHIFT',
      action = wezterm.action.CopyTo 'Clipboard',
    },
    {
      key = 'v',
      mods = platform.is_macos and 'CMD' or 'CTRL|SHIFT',
      action = wezterm.action.PasteFrom 'Clipboard',
    },
    -- Search
    {
      key = 'f',
      mods = platform.is_macos and 'CMD' or 'CTRL|SHIFT',
      action = wezterm.action.Search { CaseSensitiveString = '' },
    },
    -- New tab
    {
      key = 't',
      mods = platform.is_macos and 'CMD' or 'CTRL|SHIFT',
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
      mods = platform.is_macos and 'CMD' or 'CTRL|SHIFT',
      action = wezterm.action.TogglePaneZoomState,
    },
    -- Show launcher
    {
      key = 'l',
      mods = platform.is_macos and 'CMD|SHIFT' or 'CTRL|SHIFT|ALT',
      action = wezterm.action.ShowLauncher,
    },
    -- Reload configuration
    {
      key = 'r',
      mods = platform.is_macos and 'CMD|SHIFT' or 'CTRL|SHIFT|ALT',
      action = wezterm.action.ReloadConfiguration,
    },
  }
end

return M
