-- Tabline plugin configuration
-- Uses tabline.wez for enhanced tab bar with system information
local wezterm = require 'wezterm'

local M = {}

function M.apply(config)
  -- Load the tabline plugin
  local tabline = wezterm.plugin.require("https://github.com/michaelbrusegard/tabline.wez")

  -- Configure tabline with CPU, RAM, and clock widgets
  tabline.setup({
    options = {
      icons_enabled = true,
      theme = 'Catppuccin Latte',
      tabs_enabled = true,
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
      tabline_z = { 'hostname' },
    },
  })

  -- Apply tabline configuration to WezTerm config
  tabline.apply_to_config(config)
end

return M
