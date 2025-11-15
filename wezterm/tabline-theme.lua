-- Custom Warm Palette Theme for tabline.wez
-- Matches the warm orange/brown color scheme used throughout wezterm

local M = {}

M.WarmPalette = {
  -- Normal mode (default)
  normal_mode = {
    a = {
      fg = '#fefdf8', -- warm white
      bg = '#d97742', -- warm orange
    },
    b = {
      fg = '#5c4d3d', -- warm brown
      bg = '#f5e6d3', -- light beige
    },
    c = {
      fg = '#8b7355', -- medium brown
      bg = '#fefdf8', -- warm white background
    },
  },

  -- Copy mode
  copy_mode = {
    a = {
      fg = '#fefdf8', -- warm white
      bg = '#ebad5f', -- golden amber
    },
    b = {
      fg = '#5c4d3d', -- warm brown
      bg = '#f5e6d3', -- light beige
    },
    c = {
      fg = '#8b7355', -- medium brown
      bg = '#fefdf8', -- warm white background
    },
  },

  -- Search mode
  search_mode = {
    a = {
      fg = '#fefdf8', -- warm white
      bg = '#8a9a5b', -- warm olive
    },
    b = {
      fg = '#5c4d3d', -- warm brown
      bg = '#f5e6d3', -- light beige
    },
    c = {
      fg = '#8b7355', -- medium brown
      bg = '#fefdf8', -- warm white background
    },
  },

  -- Window mode
  window_mode = {
    a = {
      fg = '#fefdf8', -- warm white
      bg = '#7c8fa3', -- warm slate blue
    },
    b = {
      fg = '#5c4d3d', -- warm brown
      bg = '#f5e6d3', -- light beige
    },
    c = {
      fg = '#8b7355', -- medium brown
      bg = '#fefdf8', -- warm white background
    },
  },

  -- Tab colors
  tab = {
    active = {
      fg = '#fefdf8', -- warm white
      bg = '#d97742', -- warm orange
    },
    inactive = {
      fg = '#5c4d3d', -- warm brown
      bg = '#f5ede3', -- light cream
    },
    inactive_hover = {
      fg = '#5c4d3d', -- warm brown
      bg = '#edb88b', -- light orange
    },
  },
}

return M

