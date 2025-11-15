-- Custom Warm Palette Theme for tabline.wez
-- Matches the warm orange/brown color scheme used throughout wezterm

local M = {}

M.WarmPalette = {
  -- Normal mode (default)
  mode_a = {
    fg = '#fefdf8', -- warm white
    bg = '#d97742', -- warm orange
    bold = true,
  },
  mode_b = {
    fg = '#5c4d3d', -- warm brown
    bg = '#f5e6d3', -- light beige
  },
  mode_c = {
    fg = '#8b7355', -- medium brown
    bg = '#fefdf8', -- warm white background
  },

  -- Copy mode
  copy_mode_a = {
    fg = '#fefdf8', -- warm white
    bg = '#ebad5f', -- golden amber
    bold = true,
  },
  copy_mode_b = {
    fg = '#5c4d3d', -- warm brown
    bg = '#f5e6d3', -- light beige
  },
  copy_mode_c = {
    fg = '#8b7355', -- medium brown
    bg = '#fefdf8', -- warm white background
  },

  -- Search mode
  search_mode_a = {
    fg = '#fefdf8', -- warm white
    bg = '#8a9a5b', -- warm olive
    bold = true,
  },
  search_mode_b = {
    fg = '#5c4d3d', -- warm brown
    bg = '#f5e6d3', -- light beige
  },
  search_mode_c = {
    fg = '#8b7355', -- medium brown
    bg = '#fefdf8', -- warm white background
  },

  -- Window mode
  window_mode_a = {
    fg = '#fefdf8', -- warm white
    bg = '#7c8fa3', -- warm slate blue
    bold = true,
  },
  window_mode_b = {
    fg = '#5c4d3d', -- warm brown
    bg = '#f5e6d3', -- light beige
  },
  window_mode_c = {
    fg = '#8b7355', -- medium brown
    bg = '#fefdf8', -- warm white background
  },

  -- Tab colors
  tab = {
    fg = '#fefdf8', -- warm white
    bg = '#d97742', -- warm orange
    bold = true,
  },
  tab_inactive = {
    fg = '#5c4d3d', -- warm brown
    bg = '#f5ede3', -- light cream
  },
  tab_inactive_hover = {
    fg = '#5c4d3d', -- warm brown
    bg = '#edb88b', -- light orange
  },
}

return M
