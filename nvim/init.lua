-- Neovim configuration with mini.nvim
-- Modular configuration structure

-- Bootstrap mini.nvim
local path_package = vim.fn.stdpath('data') .. '/site/'
local mini_path = path_package .. 'pack/deps/start/mini.nvim'
if not vim.loop.fs_stat(mini_path) then
  vim.cmd('echo "Installing `mini.nvim`" | redraw')
  local clone_cmd = {
    'git', 'clone', '--filter=blob:none',
    'https://github.com/echasnovski/mini.nvim', mini_path
  }
  vim.fn.system(clone_cmd)
  vim.cmd('packadd mini.nvim | helptags ALL')
  vim.cmd('echo "Installed `mini.nvim`" | redraw')
end

-- Load configuration modules
require('config.options')   -- Basic options and settings
require('config.keymaps')   -- Key mappings
require('config.autocmds')  -- Auto commands

-- Plugin manager
require('mini.deps').setup({ path = { package = path_package } })
local add, now, later = MiniDeps.add, MiniDeps.now, MiniDeps.later

-- Get plugins configuration
local plugins = require('config.plugins')

-- Load essential mini.nvim plugins immediately
now(function()
  plugins.setup_mini()
  
  -- Essential keymaps for mini.files
  vim.keymap.set('n', '<leader>e', '<CMD>lua MiniFiles.open()<CR>', { desc = 'Open file explorer' })
  vim.keymap.set('n', '<leader>E', '<CMD>lua MiniFiles.open(vim.api.nvim_buf_get_name(0))<CR>', { desc = 'Open file explorer at current file' })
end)

-- Load completion and picker
later(function()
  plugins.setup_completion()
  plugins.setup_picker()
  
  -- Fuzzy finder keymaps
  vim.keymap.set('n', '<leader>ff', '<CMD>Pick files<CR>', { desc = 'Find files' })
  vim.keymap.set('n', '<leader>fg', '<CMD>Pick grep_live<CR>', { desc = 'Live grep' })
  vim.keymap.set('n', '<leader>fb', '<CMD>Pick buffers<CR>', { desc = 'Find buffers' })
  vim.keymap.set('n', '<leader>fh', '<CMD>Pick help<CR>', { desc = 'Find help' })
  vim.keymap.set('n', '<leader>fr', '<CMD>Pick oldfiles<CR>', { desc = 'Recent files' })
  vim.keymap.set('n', '<leader>fd', '<CMD>Pick diagnostic<CR>', { desc = 'Find diagnostics' })
  vim.keymap.set('n', '<leader>fk', '<CMD>Pick keymaps<CR>', { desc = 'Find keymaps' })
  vim.keymap.set('n', '<leader>fc', '<CMD>Pick commands<CR>', { desc = 'Find commands' })
  vim.keymap.set('n', '<leader>fm', '<CMD>Pick marks<CR>', { desc = 'Find marks' })
  vim.keymap.set('n', '<leader>fo', '<CMD>Pick options<CR>', { desc = 'Find options' })
end)

-- Load git integration
later(function()
  plugins.setup_git()
end)

-- Load color scheme
later(function()
  add({
    source = 'catppuccin/nvim',
    name = 'catppuccin',
  })
  plugins.setup_colorscheme()
end)

-- Load treesitter
later(function()
  add({
    source = 'nvim-treesitter/nvim-treesitter',
    hooks = {
      post_checkout = function()
        vim.cmd('TSUpdate')
      end,
    },
  })
  plugins.setup_treesitter()
end)

-- LSP configuration
later(function()
  -- LSP servers list
  local lsp_servers = {
    'lua_ls',
    'pyright',
    'rust_analyzer',
    'tsserver',
    'gopls',
    'bashls',
    'jsonls',
    'yamlls',
    'html',
    'cssls',
    'dockerls',
    'terraformls',
  }

  -- Auto-install LSP servers command
  vim.api.nvim_create_user_command('LspInstall', function(opts)
    local server = opts.args
    if server == '' then
      vim.notify('Please specify a server name', vim.log.levels.ERROR)
      return
    end
    local cmd = string.format('!npm install -g %s', server)
    vim.cmd(cmd)
  end, { nargs = 1 })
end)