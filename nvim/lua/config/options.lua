-- Neovim options configuration

-- Leader keys
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Basic options
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.scrolloff = 8
vim.opt.sidescrolloff = 8
vim.opt.signcolumn = 'yes'
vim.opt.updatetime = 250
vim.opt.timeoutlen = 300

-- File handling
vim.opt.backup = false
vim.opt.writebackup = false
vim.opt.swapfile = false
vim.opt.undofile = true
vim.opt.undodir = vim.fn.stdpath('state') .. '/undo'

-- Search
vim.opt.hlsearch = true
vim.opt.incsearch = true
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- Appearance
vim.opt.termguicolors = true
vim.opt.showmode = false
vim.opt.wrap = false
vim.opt.breakindent = true
vim.opt.linebreak = true
vim.opt.list = true
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }

-- Completion
vim.opt.completeopt = 'menuone,noselect'
vim.opt.pumheight = 10

-- Splits
vim.opt.splitbelow = true
vim.opt.splitright = true

-- Indentation
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true
vim.opt.smartindent = true
vim.opt.autoindent = true

-- Mouse and clipboard
vim.opt.mouse = 'a'
vim.opt.clipboard = 'unnamedplus'

-- Folding (using built-in Neovim treesitter API)
vim.opt.foldmethod = 'expr'
vim.opt.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
vim.opt.foldtext = ''  -- Use default fold text (shows first line)
vim.opt.foldlevel = 99
vim.opt.foldlevelstart = 99
vim.opt.foldenable = true

-- Window title
vim.opt.title = true
vim.opt.titlestring = '%t - Neovim'

-- Command line
vim.opt.cmdheight = 1
vim.opt.showcmd = true

-- Status line
vim.opt.laststatus = 3 -- Global statusline

-- Other options
vim.opt.confirm = true
vim.opt.hidden = true
vim.opt.spell = false
vim.opt.spelllang = { 'en_us' }
vim.opt.conceallevel = 0
vim.opt.cursorline = true
vim.opt.winminwidth = 5