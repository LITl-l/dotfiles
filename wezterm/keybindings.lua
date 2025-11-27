-- Keyboard shortcuts configuration with leader key
local wezterm = require 'wezterm'
local platform = require 'platform'

local M = {}

function M.apply(config)
  -- Leader key: CTRL+Space with 1 second timeout
  config.leader = { key = 'Space', mods = 'CTRL', timeout_milliseconds = 1000 }

  config.keys = {
    -- ============================================
    -- Pane operations (LEADER + key)
    -- ============================================

    -- Split panes
    {
      key = 'd',
      mods = 'LEADER',
      action = wezterm.action.SplitVertical { domain = 'CurrentPaneDomain' },
    },
    {
      key = 'd',
      mods = 'LEADER|SHIFT',
      action = wezterm.action.SplitHorizontal { domain = 'CurrentPaneDomain' },
    },

    -- Navigate panes (vim-style)
    {
      key = 'h',
      mods = 'LEADER',
      action = wezterm.action.ActivatePaneDirection 'Left',
    },
    {
      key = 'l',
      mods = 'LEADER',
      action = wezterm.action.ActivatePaneDirection 'Right',
    },
    {
      key = 'k',
      mods = 'LEADER',
      action = wezterm.action.ActivatePaneDirection 'Up',
    },
    {
      key = 'j',
      mods = 'LEADER',
      action = wezterm.action.ActivatePaneDirection 'Down',
    },

    -- Resize panes (LEADER + SHIFT + hjkl)
    {
      key = 'h',
      mods = 'LEADER|SHIFT',
      action = wezterm.action.AdjustPaneSize { 'Left', 5 },
    },
    {
      key = 'l',
      mods = 'LEADER|SHIFT',
      action = wezterm.action.AdjustPaneSize { 'Right', 5 },
    },
    {
      key = 'k',
      mods = 'LEADER|SHIFT',
      action = wezterm.action.AdjustPaneSize { 'Up', 5 },
    },
    {
      key = 'j',
      mods = 'LEADER|SHIFT',
      action = wezterm.action.AdjustPaneSize { 'Down', 5 },
    },

    -- Close pane
    {
      key = 'w',
      mods = 'LEADER',
      action = wezterm.action.CloseCurrentPane { confirm = true },
    },

    -- Zoom pane
    {
      key = 'z',
      mods = 'LEADER',
      action = wezterm.action.TogglePaneZoomState,
    },

    -- ============================================
    -- Tab operations (LEADER + key)
    -- ============================================

    -- New tab
    {
      key = 't',
      mods = 'LEADER',
      action = wezterm.action.SpawnTab 'CurrentPaneDomain',
    },

    -- Switch tabs
    {
      key = 'n',
      mods = 'LEADER',
      action = wezterm.action.ActivateTabRelative(1),
    },
    {
      key = 'p',
      mods = 'LEADER',
      action = wezterm.action.ActivateTabRelative(-1),
    },

    -- ============================================
    -- Utility operations (LEADER + key)
    -- ============================================

    -- Search
    {
      key = 'f',
      mods = 'LEADER',
      action = wezterm.action.Search { CaseSensitiveString = '' },
    },

    -- Show launcher
    {
      key = 'Space',
      mods = 'LEADER',
      action = wezterm.action.ShowLauncher,
    },

    -- Reload configuration
    {
      key = 'r',
      mods = 'LEADER',
      action = wezterm.action.ReloadConfiguration,
    },

    -- ============================================
    -- Direct keybindings (no leader required)
    -- ============================================

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
  }
end

return M
