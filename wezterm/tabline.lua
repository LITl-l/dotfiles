-- Tabline plugin configuration
-- Uses tabline.wez for enhanced tab bar with system information
local wezterm = require 'wezterm'
local tabline_theme = require 'tabline-theme'

local M = {}

-- CapsLock indicator extension for tabline
-- Only shows "CAPS" when CapsLock is enabled
local function caps_lock_extension(window)
  local led_state = window:keyboard_modifiers()
  if led_state.caps_lock then
    return 'CAPS'
  end
  return ''
end

function M.apply(config)
  -- Load the tabline plugin with error handling
  local success, tabline = pcall(function()
    return wezterm.plugin.require("https://github.com/michaelbrusegard/tabline.wez")
  end)

  if not success then
    wezterm.log_error("Failed to load tabline plugin: " .. tostring(tabline))
    -- Fall back to basic tab bar configuration
    config.use_fancy_tab_bar = false
    config.hide_tab_bar_if_only_one_tab = false
    return
  end

  -- Configure tabline with CPU, RAM, and clock widgets (warm white, orange, brown aesthetic)
  tabline.setup({
    options = {
      icons_enabled = true,
      tabs_enabled = true,
      -- Round separators for a softer, more elegant look
      section_separators = {
        left = wezterm.nerdfonts.ple_right_half_circle_thick,
        right = wezterm.nerdfonts.ple_left_half_circle_thick,
      },
      component_separators = {
        left = wezterm.nerdfonts.ple_right_half_circle_thin,
        right = wezterm.nerdfonts.ple_left_half_circle_thin,
      },
      tab_separators = {
        left = wezterm.nerdfonts.ple_right_half_circle_thick,
        right = wezterm.nerdfonts.ple_left_half_circle_thick,
      },
      -- Custom warm palette theme
      theme_overrides = tabline_theme.WarmPalette,
    },
    sections = {
      tabline_a = { 'mode' },
      tabline_b = { 'workspace' },
      tabline_c = { ' ' },
      tab_active = {
        'index',
        { 'parent', padding = 0 },
        '/',
        { 'cwd', padding = { left = 0, right = 1 } },
        '|',
        { 'process', padding = { left = 1, right = 0} },
      },
      tab_inactive = {
        'index',
        { 'process', padding = { left = 0, right = 1 } }
      },
      tabline_x = {
        { caps_lock_extension, padding = 1 },
        { 'ram', padding = 1 },
        { 'cpu', padding = 1 },
      },
      tabline_y = {
        { 'datetime', padding = 1 },
      },
      tabline_z = {},
    },
  })

  -- Apply tabline configuration to WezTerm config
  tabline.apply_to_config(config)
end

return M

