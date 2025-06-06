-- Neovim configuration with mini.nvim

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

-- Set leader key
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Basic options
require('mini.basics').setup({
  options = {
    basic = true,
    extra_ui = true,
    win_borders = 'default',
  },
  mappings = {
    basic = true,
    option_toggle_prefix = [[\]],
    windows = true,
    move_with_alt = true,
  },
  autocommands = {
    basic = true,
    relnum_in_visual_mode = true,
  },
  silent = false,
})

-- Additional options
vim.opt.relativenumber = true
vim.opt.scrolloff = 8
vim.opt.sidescrolloff = 8
vim.opt.signcolumn = 'yes'
vim.opt.updatetime = 250
vim.opt.timeoutlen = 300
vim.opt.backup = false
vim.opt.writebackup = false
vim.opt.swapfile = false
vim.opt.undofile = true
vim.opt.undodir = vim.fn.stdpath('state') .. '/undo'
vim.opt.hlsearch = true
vim.opt.incsearch = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.termguicolors = true
vim.opt.completeopt = 'menuone,noselect'
vim.opt.pumheight = 10
vim.opt.showmode = false
vim.opt.splitbelow = true
vim.opt.splitright = true
vim.opt.wrap = false
vim.opt.breakindent = true
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true
vim.opt.smartindent = true
vim.opt.list = true
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }
vim.opt.mouse = 'a'
vim.opt.clipboard = 'unnamedplus'

-- Plugin manager
require('mini.deps').setup({ path = { package = path_package } })
local add, now, later = MiniDeps.add, MiniDeps.now, MiniDeps.later

-- Add mini.nvim modules
now(function()
  -- File explorer
  require('mini.files').setup({
    mappings = {
      close       = 'q',
      go_in       = 'l',
      go_in_plus  = '<CR>',
      go_out      = 'h',
      go_out_plus = '-',
      reset       = '<BS>',
      reveal_cwd  = '@',
      show_help   = 'g?',
      synchronize = '=',
      trim_left   = '<',
      trim_right  = '>',
    },
    windows = {
      preview = true,
      width_focus = 30,
      width_preview = 60,
    },
  })
  vim.keymap.set('n', '<leader>e', '<CMD>lua MiniFiles.open()<CR>', { desc = 'Open file explorer' })
  vim.keymap.set('n', '<leader>E', '<CMD>lua MiniFiles.open(vim.api.nvim_buf_get_name(0))<CR>', { desc = 'Open file explorer at current file' })

  -- Statusline
  require('mini.statusline').setup({
    use_icons = true,
    set_vim_settings = true,
  })

  -- Tabline
  require('mini.tabline').setup()

  -- Comments
  require('mini.comment').setup()

  -- Surround
  require('mini.surround').setup()

  -- Pairs
  require('mini.pairs').setup()

  -- Move lines
  require('mini.move').setup()

  -- Better text objects
  require('mini.ai').setup()

  -- Split/join
  require('mini.splitjoin').setup()

  -- Indentscope
  require('mini.indentscope').setup({
    symbol = '│',
    draw = {
      delay = 100,
      animation = require('mini.indentscope').gen_animation.none(),
    },
  })

  -- Highlight patterns
  require('mini.hipatterns').setup({
    highlighters = {
      fixme = { pattern = '%f[%w]()FIXME()%f[%W]', group = 'MiniHipatternsFixme' },
      hack  = { pattern = '%f[%w]()HACK()%f[%W]',  group = 'MiniHipatternsHack'  },
      todo  = { pattern = '%f[%w]()TODO()%f[%W]',  group = 'MiniHipatternsTodo'  },
      note  = { pattern = '%f[%w]()NOTE()%f[%W]',  group = 'MiniHipatternsNote'  },
    },
  })

  -- Trailing whitespace
  require('mini.trailspace').setup()

  -- Session management
  require('mini.sessions').setup({
    autoread = false,
    autowrite = true,
    directory = vim.fn.stdpath('state') .. '/sessions',
    file = 'session.vim',
  })

  -- Starter
  require('mini.starter').setup({
    evaluate_single = true,
    items = {
      require('mini.starter').sections.builtin_actions(),
      require('mini.starter').sections.recent_files(5, false),
      require('mini.starter').sections.recent_files(5, true),
      require('mini.starter').sections.sessions(5, true),
    },
    content_hooks = {
      require('mini.starter').gen_hook.adding_bullet(),
      require('mini.starter').gen_hook.aligning('center', 'center'),
    },
  })
end)

-- Completion and LSP
later(function()
  -- Completion
  require('mini.completion').setup({
    delay = { completion = 100, info = 100, signature = 50 },
    window = {
      info = { height = 25, width = 80, border = 'single' },
      signature = { height = 25, width = 80, border = 'single' },
    },
    lsp_completion = {
      source_func = 'omnifunc',
      auto_setup = false,
    },
    fallback_action = '<C-x><C-n>',
  })

  -- Fuzzy finder
  require('mini.pick').setup()
  vim.keymap.set('n', '<leader>ff', '<CMD>Pick files<CR>', { desc = 'Find files' })
  vim.keymap.set('n', '<leader>fg', '<CMD>Pick grep_live<CR>', { desc = 'Live grep' })
  vim.keymap.set('n', '<leader>fb', '<CMD>Pick buffers<CR>', { desc = 'Find buffers' })
  vim.keymap.set('n', '<leader>fh', '<CMD>Pick help<CR>', { desc = 'Find help' })
  vim.keymap.set('n', '<leader>fr', '<CMD>Pick oldfiles<CR>', { desc = 'Recent files' })
  vim.keymap.set('n', '<leader>fd', '<CMD>Pick diagnostic<CR>', { desc = 'Find diagnostics' })

  -- Extra picker
  require('mini.extra').setup()
  vim.keymap.set('n', '<leader>fk', '<CMD>Pick keymaps<CR>', { desc = 'Find keymaps' })
  vim.keymap.set('n', '<leader>fc', '<CMD>Pick commands<CR>', { desc = 'Find commands' })
  vim.keymap.set('n', '<leader>fm', '<CMD>Pick marks<CR>', { desc = 'Find marks' })
  vim.keymap.set('n', '<leader>fo', '<CMD>Pick options<CR>', { desc = 'Find options' })
end)

-- Git integration
later(function()
  require('mini.git').setup()
  require('mini.diff').setup({
    view = {
      style = 'sign',
      signs = { add = '+', change = '~', delete = '-' },
    },
  })
end)

-- Color scheme
later(function()
  add({
    source = 'catppuccin/nvim',
    name = 'catppuccin',
  })
  require('catppuccin').setup({
    flavour = 'mocha',
    transparent_background = false,
    term_colors = true,
    integrations = {
      mini = {
        enabled = true,
        indentscope_color = '',
      },
    },
  })
  vim.cmd.colorscheme('catppuccin')
end)

-- LSP configuration
later(function()
  -- Setup LSP servers
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

  -- Auto-install LSP servers
  vim.api.nvim_create_user_command('LspInstall', function(opts)
    local server = opts.args
    if server == '' then
      vim.notify('Please specify a server name', vim.log.levels.ERROR)
      return
    end
    local cmd = string.format('!npm install -g %s', server)
    vim.cmd(cmd)
  end, { nargs = 1 })

  -- LSP keymaps
  vim.api.nvim_create_autocmd('LspAttach', {
    group = vim.api.nvim_create_augroup('UserLspConfig', {}),
    callback = function(ev)
      local opts = { buffer = ev.buf }
      vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts)
      vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
      vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
      vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)
      vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, opts)
      vim.keymap.set('n', '<leader>wa', vim.lsp.buf.add_workspace_folder, opts)
      vim.keymap.set('n', '<leader>wr', vim.lsp.buf.remove_workspace_folder, opts)
      vim.keymap.set('n', '<leader>wl', function()
        print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
      end, opts)
      vim.keymap.set('n', '<leader>D', vim.lsp.buf.type_definition, opts)
      vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, opts)
      vim.keymap.set({ 'n', 'v' }, '<leader>ca', vim.lsp.buf.code_action, opts)
      vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
      vim.keymap.set('n', '<leader>f', function()
        vim.lsp.buf.format { async = true }
      end, opts)
    end,
  })
end)

-- Treesitter
later(function()
  add({
    source = 'nvim-treesitter/nvim-treesitter',
    hooks = {
      post_checkout = function()
        vim.cmd('TSUpdate')
      end,
    },
  })
  require('nvim-treesitter.configs').setup({
    ensure_installed = {
      'lua', 'vim', 'vimdoc', 'query',
      'javascript', 'typescript', 'tsx',
      'python', 'rust', 'go',
      'html', 'css', 'json', 'yaml', 'toml',
      'bash', 'markdown', 'markdown_inline',
    },
    highlight = { enable = true },
    indent = { enable = true },
  })
end)

-- Additional keymaps
vim.keymap.set('n', '<leader>w', '<CMD>write<CR>', { desc = 'Save file' })
vim.keymap.set('n', '<leader>q', '<CMD>quit<CR>', { desc = 'Quit' })
vim.keymap.set('n', '<leader>Q', '<CMD>qall!<CR>', { desc = 'Quit all' })
vim.keymap.set('n', '<C-h>', '<C-w>h', { desc = 'Go to left window' })
vim.keymap.set('n', '<C-j>', '<C-w>j', { desc = 'Go to lower window' })
vim.keymap.set('n', '<C-k>', '<C-w>k', { desc = 'Go to upper window' })
vim.keymap.set('n', '<C-l>', '<C-w>l', { desc = 'Go to right window' })
vim.keymap.set('n', '<leader>-', '<CMD>split<CR>', { desc = 'Horizontal split' })
vim.keymap.set('n', '<leader>|', '<CMD>vsplit<CR>', { desc = 'Vertical split' })
vim.keymap.set('n', '<Esc>', '<CMD>nohlsearch<CR>', { desc = 'Clear search highlights' })