-- Set <space> as the leader key
-- See `:help mapleader`
--  NOTE: Must happen before plugins are required (otherwise wrong leader will be used)
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Install package manager
--    https_proxy=http://<proxy-host>:<proxy-port> git clone ...
local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system {
    'git',
    'clone',
    '--filter=blob:none',
    'https://github.com/folke/lazy.nvim.git',
    '--branch=stable', -- latest stable release
    lazypath,
  }
end
vim.opt.rtp:prepend(lazypath)

-- NOTE: Here is where you install your plugins.
--  You can configure plugins using the `config` key.
--
--  You can also configure plugins after the setup call,
--    as they will be available in your neovim runtime.
require('lazy').setup({
  -- NOTE: First, some plugins that don't require any configuration
  'RRethy/vim-illuminate',

  -- NOTE: Read the docs for managing headlines successfully
  --    https://github.com/nvim-orgmode/orgmode
  {
    'nvim-orgmode/orgmode',
    dependencies = {
      { 'nvim-treesitter/nvim-treesitter', lazy = true },
    },
    ft = { 'org' },
  },

  { -- Useful plugin to show you pending keybinds.
    'folke/which-key.nvim',
    opts = {}
  },

  -- Themes
  { 'folke/tokyonight.nvim', name = 'tokyonight', lazy = false, priority = 1000 },

  -- Add any additional plugins here
  -- ...

  -- NOTE: This is where your plugins will be fully loaded and configured. For example:
  -- {
  --   "nvim-treesitter/nvim-treesitter",
  --   build = ":TSUpdate",
  --   config = function()
  --     require("nvim-treesitter.configs").setup {
  --       ensure_installed = { "python", "lua", "vim", "vimdoc", "markdown", "c" },
  --       highlight = { enable = true },
  --     }
  --   end,
  -- },
})

-- Set colorscheme
vim.cmd.colorscheme 'tokyonight'

-- Keymappings
vim.keymap.set('n', '<Leader>w', '<cmd>write<cr>', { desc = 'Save file' })
vim.keymap.set('n', '<Leader>q', '<cmd>quit<cr>', { desc = 'Quit Neovim' })

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
