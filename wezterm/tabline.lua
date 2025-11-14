-- Tabline plugin configuration
-- Uses tabline.wez for enhanced tab bar with system information
local wezterm = require 'wezterm'

local M = {}

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
      theme = 'Catppuccin Latte',  -- Base theme (will be heavily overridden)
      tabs_enabled = true,
      -- Round separators for a softer, more elegant look
      section_separators = {
        left = wezterm.nerdfonts.ple_left_half_circle_thick,
        right = wezterm.nerdfonts.ple_right_half_circle_thick,
      },
      component_separators = {
        left = wezterm.nerdfonts.ple_left_half_circle_thin,
        right = wezterm.nerdfonts.ple_right_half_circle_thin,
      },
      tab_separators = {
        left = wezterm.nerdfonts.ple_left_half_circle_thick,
        right = wezterm.nerdfonts.ple_right_half_circle_thick,
      },
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
      },
      tab_inactive = {
        'index',
        { 'process', padding = { left = 0, right = 1 } }
      },
      tabline_x = {
        { 'ram', padding = 1 },
        { 'cpu', padding = 1 },
      },
      tabline_y = {
        { 'datetime', padding = 1 },
      },
      tabline_z = {},
    },
    -- Custom color overrides to match warm white, orange, brown palette
    theme_overrides = {
      normal_mode = {
        -- Mode indicator (left) - warm orange accent (matches theme cursor)
        a = { fg = '#fefdf8', bg = '#d97742', intensity = 'Bold' },
        -- Workspace section - enhanced cream with darker warm brown for better contrast
        b = { fg = '#5c4d3d', bg = '#f5e6d3' },
        -- Middle section - very light warm background with medium brown text
        c = { fg = '#8b7355', bg = '#fefdf8' },
      },
      copy_mode = {
        -- Copy mode - golden amber (brighter warm variant)
        a = { fg = '#fefdf8', bg = '#ebad5f', intensity = 'Bold' },
        b = { fg = '#5c4d3d', bg = '#f5e6d3' },
        c = { fg = '#8b7355', bg = '#fefdf8' },
      },
      search_mode = {
        -- Search mode - warm olive green (from ansi palette)
        a = { fg = '#fefdf8', bg = '#8a9a5b', intensity = 'Bold' },
        b = { fg = '#5c4d3d', bg = '#f5e6d3' },
        c = { fg = '#8b7355', bg = '#fefdf8' },
      },
      window_mode = {
        -- Window mode - warm slate blue (from ansi palette)
        a = { fg = '#fefdf8', bg = '#7c8fa3', intensity = 'Bold' },
        b = { fg = '#5c4d3d', bg = '#f5e6d3' },
        c = { fg = '#8b7355', bg = '#fefdf8' },
      },
      -- Active tab - warm orange with white text (matches theme.lua active_tab)
      tab = {
        fg = '#fefdf8',
        bg = '#d97742',
        intensity = 'Bold',
      },
      -- Inactive tab - light beige with medium brown text (enhanced contrast)
      tab_inactive = {
        fg = '#5c4d3d',
        bg = '#f5ede3',
      },
      -- Inactive tab hover - light orange with warm brown (matches theme.lua)
      tab_inactive_hover = {
        fg = '#5c4d3d',
        bg = '#edb88b',
      },
    },
  })

  -- Apply tabline configuration to WezTerm config
  tabline.apply_to_config(config)
end

return M

