-- Set <space> as the leader key
-- See `:help mapleader`
--  NOTE: Must happen before plugins are required (otherwise wrong leader will be used)
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Setup mini.hues for theming
-- This replaces the previous `vim.cmd.colorscheme 'tokyonight'`
require('mini.hues').setup({
  background = '#1e1e2e', -- A slightly bluish dark background (Catppuccin Macchiato base)
  foreground = '#cdd6f4', -- Catppuccin Macchiato text

  -- Palette for a futuristic look with vibrant accents
  -- Using Catppuccin Macchiato palette as a base for a cohesive, modern feel
  palette = {
    -- Base colors
    base = '#1e1e2e',     -- Background
    surface0 = '#313244', -- Slightly lighter background for UI elements
    surface1 = '#45475a', -- Even lighter for hovered items, etc.
    surface2 = '#585b70',
    overlay0 = '#6c7086',
    overlay1 = '#7f849c',
    overlay2 = '#9399b2',
    text = '#cdd6f4',     -- Main foreground
    subtext0 = '#a6adc8',
    subtext1 = '#bac2de',

    -- Accents (using Catppuccin's vibrant colors)
    rosewater = '#f5e0dc',
    flamingo = '#f2cdcd',
    pink = '#f5c2e7',
    mauve = '#cba6f7',    -- Primary accent - a vibrant purple/magenta
    red = '#f38ba8',
    maroon = '#eba0ac',
    peach = '#fab387',
    yellow = '#f9e2af',
    green = '#a6e3a1',
    teal = '#94e2d5',
    sky = '#89dceb',      -- Secondary accent - a bright cyan
    sapphire = '#74c7ec',
    blue = '#89b4fa',     -- Tertiary accent - a nice blue
    lavender = '#b4befe',
  },

  -- Define which palette color to use for `accent`
  -- Let's use 'mauve' (a vibrant purple) as the primary accent
  accent = 'mauve',

  -- Automatically start and apply the theme
  autostart = true
})


-- [[ Basic Autocommands ]]
--  See `:help lua-guide-autocommands`

-- Highlight when yanking (copying) text
--  Try it with `yap` in normal mode
--  See `:help vim.highlight.on_yank()`
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})
