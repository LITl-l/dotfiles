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
