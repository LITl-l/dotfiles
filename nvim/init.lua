-- Neovim configuration with mini.nvim
-- Modular configuration structure

-- Cache Lua modules when supported (Neovim 0.9+)
if vim.loader then
  vim.loader.enable()
end

-- Bootstrap mini.nvim. Nix provides mini.nvim for the Home Manager setup;
-- cloning is only a fallback for standalone use.
local path_package = vim.fn.stdpath('data') .. '/site/'
local mini_path = path_package .. 'pack/deps/start/mini.nvim'
local has_mini_deps = pcall(require, 'mini.deps')
if not has_mini_deps then
  local uv = vim.uv or vim.loop
  local installed = false
  if not uv.fs_stat(mini_path) then
    vim.cmd('echo "Installing `mini.nvim`" | redraw')
    local clone_cmd = {
      'git', 'clone', '--filter=blob:none',
      'https://github.com/echasnovski/mini.nvim', mini_path,
    }
    vim.fn.system(clone_cmd)
    installed = true
    vim.cmd('echo "Installed `mini.nvim`" | redraw')
  end
  vim.cmd('packadd mini.nvim')
  if installed then
    vim.cmd('helptags ALL')
  end
end

-- Load configuration modules
require('config.options')   -- Basic options and settings
require('config.keymaps')   -- Key mappings
require('config.autocmds')  -- Auto commands

-- Plugin manager
require('mini.deps').setup({ path = { package = path_package } })

-- Plugin configuration helpers
local plugins = require('config.plugins')

-- Startup-critical setup only
plugins.setup_core()
plugins.setup_colorscheme()
plugins.setup_treesitter()

-- File explorer keymaps. These stay global so LSP buffers do not shadow them.
vim.keymap.set('n', '<leader>e', function()
  plugins.open_files()
end, { desc = 'Open file explorer' })
vim.keymap.set('n', '<leader>E', function()
  plugins.open_files(vim.api.nvim_buf_get_name(0))
end, { desc = 'Open file explorer at current file' })

-- Fuzzy finder keymaps lazy-load mini.pick and mini.extra on first use.
vim.keymap.set('n', '<leader>ff', function() plugins.pick('files') end, { desc = 'Find files' })
vim.keymap.set('n', '<leader>fg', function() plugins.pick('grep_live') end, { desc = 'Live grep' })
vim.keymap.set('n', '<leader>fb', function() plugins.pick('buffers') end, { desc = 'Find buffers' })
vim.keymap.set('n', '<leader>fh', function() plugins.pick('help') end, { desc = 'Find help' })
vim.keymap.set('n', '<leader>fr', function() plugins.pick('oldfiles') end, { desc = 'Recent files' })
vim.keymap.set('n', '<leader>fd', function() plugins.pick('diagnostic') end, { desc = 'Find diagnostics' })
vim.keymap.set('n', '<leader>fk', function() plugins.pick('keymaps') end, { desc = 'Find keymaps' })
vim.keymap.set('n', '<leader>fc', function() plugins.pick('commands') end, { desc = 'Find commands' })
vim.keymap.set('n', '<leader>fm', function() plugins.pick('marks') end, { desc = 'Find marks' })
vim.keymap.set('n', '<leader>fo', function() plugins.pick('options') end, { desc = 'Find options' })
vim.keymap.set('n', '<leader>fC', function() plugins.pick_colorschemes() end, { desc = 'Pick colorscheme' })

-- Git blame: toggle inline per-line blame. Lazy-loads config.blame on first use.
-- Works in jj workspaces with no `.git` (uses `jj file annotate`) and falls back
-- to `git blame` elsewhere.
vim.keymap.set('n', '<leader>gb', function() require('config.blame').toggle() end, { desc = 'Toggle inline blame' })
vim.api.nvim_create_user_command('BlameToggle', function() require('config.blame').toggle() end, { desc = 'Toggle inline git/jj blame' })

-- Debug keymaps lazy-load DAP on first use, then config.dap replaces these stubs.
local function with_dap(callback)
  return function()
    plugins.setup_dap()
    local ok, dap = pcall(require, 'dap')
    if ok then
      callback(dap)
    end
  end
end

vim.keymap.set('n', '<leader>db', with_dap(function(dap) dap.toggle_breakpoint() end), { desc = '[D]ebug [B]reakpoint toggle' })
vim.keymap.set('n', '<leader>dB', with_dap(function(dap)
  dap.set_breakpoint(vim.fn.input('Breakpoint condition: '))
end), { desc = '[D]ebug [B]reakpoint conditional' })
vim.keymap.set('n', '<leader>dc', with_dap(function(dap) dap.continue() end), { desc = '[D]ebug [C]ontinue' })
vim.keymap.set('n', '<leader>di', with_dap(function(dap) dap.step_into() end), { desc = '[D]ebug step [I]nto' })
vim.keymap.set('n', '<leader>do', with_dap(function(dap) dap.step_over() end), { desc = '[D]ebug step [O]ver' })
vim.keymap.set('n', '<leader>dO', with_dap(function(dap) dap.step_out() end), { desc = '[D]ebug step [O]ut' })
vim.keymap.set('n', '<leader>dr', with_dap(function(dap) dap.repl.open() end), { desc = '[D]ebug [R]EPL' })
vim.keymap.set('n', '<leader>dl', with_dap(function(dap) dap.run_last() end), { desc = '[D]ebug [L]ast' })
vim.keymap.set('n', '<leader>dx', with_dap(function(dap) dap.terminate() end), { desc = '[D]ebug terminate' })

local function with_dapui(callback)
  return function()
    plugins.setup_dap()
    local ok, dapui = pcall(require, 'dapui')
    if ok then
      callback(dapui)
    end
  end
end

vim.keymap.set('n', '<leader>du', with_dapui(function(dapui) dapui.toggle() end), { desc = '[D]ebug [U]I toggle' })
vim.keymap.set('n', '<leader>de', with_dapui(function(dapui) dapui.eval() end), { desc = '[D]ebug [E]val' })
vim.keymap.set('v', '<leader>de', with_dapui(function(dapui) dapui.eval() end), { desc = '[D]ebug [E]val' })

-- Load editing features when they become useful, not during empty startup.
local lazy_group = vim.api.nvim_create_augroup('LazyPluginSetup', { clear = true })

vim.api.nvim_create_autocmd('InsertEnter', {
  group = lazy_group,
  once = true,
  callback = function()
    plugins.setup_editing()
    plugins.setup_completion()
    plugins.setup_format()
    require('config.snippets').setup()
  end,
})

vim.api.nvim_create_autocmd({ 'BufReadPre', 'BufNewFile' }, {
  group = lazy_group,
  once = true,
  callback = function()
    -- Let the buffer paint first, then warm up editing/git/LSP/format on the
    -- next loop tick. Starting the LSP client pulls in the vim.lsp.* runtime
    -- (~0.7s on this WSL box) and must not block the file from appearing.
    local buf = vim.api.nvim_get_current_buf()
    vim.schedule(function()
      plugins.setup_editing()
      plugins.setup_git()
      plugins.setup_lsp()
      plugins.setup_format()
      -- setup_lsp() enables the servers only now — after this buffer's FileType
      -- already fired — so re-emit FileType to attach them to the open buffer.
      if vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_exec_autocmds('FileType', { buffer = buf })
      end
    end)
  end,
})

-- which-key is useful, but it does not need to block first paint.
vim.defer_fn(function()
  pcall(plugins.setup_whichkey)
end, 100)
