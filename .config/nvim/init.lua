-- Initialize mini.nvim
-- IMPORTANT: See init.lua section of `mini.nvim` :help for what to do here
local minipath = vim.fn.stdpath('data') .. '/mini'
if not vim.loop.fs_stat(minipath .. '/lua/mini.nvim') then
  local clone_cmd = {
    'git', 'clone', '--filter=blob:none',
    'https://github.com/echasnovski/mini.nvim', minipath
  }
  -- Use this instead if you want to control version of `mini.nvim`
  -- local clone_cmd = {
  --   'git', 'clone', '--filter=blob:none', '--branch', 'stable',
  --   'https://github.com/echasnovski/mini.nvim', minipath
  -- }
  print('Cloning `mini.nvim` from GitHub...')
  vim.fn.system(clone_cmd)
  print('Done.')
end
vim.opt.rtp:prepend(minipath)

-- Load plugin configuration
require('plugins')

-- Load options
require('options')

-- Load keymaps
require('keymaps')
