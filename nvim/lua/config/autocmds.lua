-- Neovim autocommands configuration

local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

-- General settings
local general = augroup("General", { clear = true })

-- Check if we need to reload the file when it changed
autocmd({ "FocusGained", "TermClose", "TermLeave" }, {
  group = general,
  command = "checktime",
})

-- Highlight on yank
autocmd("TextYankPost", {
  group = general,
  callback = function()
    vim.highlight.on_yank()
  end,
})

-- Resize splits if window got resized
autocmd({ "VimResized" }, {
  group = general,
  callback = function()
    local current_tab = vim.fn.tabpagenr()
    vim.cmd("tabdo wincmd =")
    vim.cmd("tabnext " .. current_tab)
  end,
})

-- Go to last loc when opening a buffer
autocmd("BufReadPost", {
  group = general,
  callback = function(event)
    local exclude = { "gitcommit" }
    local buf = event.buf
    if vim.tbl_contains(exclude, vim.bo[buf].filetype) or vim.b[buf].last_loc then
      return
    end
    vim.b[buf].last_loc = true
    local mark = vim.api.nvim_buf_get_mark(buf, '"')
    local lcount = vim.api.nvim_buf_line_count(buf)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Close some filetypes with <q>
autocmd("FileType", {
  group = general,
  pattern = {
    "PlenaryTestPopup",
    "help",
    "lspinfo",
    "man",
    "notify",
    "qf",
    "query",
    "spectre_panel",
    "startuptime",
    "tsplayground",
    "neotest-output",
    "checkhealth",
    "neotest-summary",
    "neotest-output-panel",
  },
  callback = function(event)
    vim.bo[event.buf].buflisted = false
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = event.buf, silent = true })
  end,
})

-- Wrap and check for spell in text filetypes
autocmd("FileType", {
  group = general,
  pattern = { "gitcommit", "markdown" },
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.spell = true
  end,
})

-- Fix conceallevel for json files
autocmd({ "FileType" }, {
  group = general,
  pattern = { "json", "jsonc", "json5" },
  callback = function()
    vim.opt_local.conceallevel = 0
  end,
})

-- Auto create dir when saving a file, in case some intermediate directory does not exist
autocmd({ "BufWritePre" }, {
  group = general,
  callback = function(event)
    if event.match:match("^%w%w+://") then
      return
    end
    local file = vim.loop.fs_realpath(event.match) or event.match
    vim.fn.mkdir(vim.fn.fnamemodify(file, ":p:h"), "p")
  end,
})

-- Terminal settings
local terminal = augroup("Terminal", { clear = true })

autocmd("TermOpen", {
  group = terminal,
  callback = function()
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
    vim.opt_local.scrolloff = 0
    vim.cmd("startinsert")
  end,
})

-- LSP settings
local lsp = augroup("LspAttach", { clear = true })

autocmd("LspAttach", {
  group = lsp,
  callback = function(event)
    local map = function(keys, func, desc)
      vim.keymap.set('n', keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
    end

    -- Lspsaga enhanced features
    map('K', '<cmd>Lspsaga hover_doc<cr>', 'Hover Documentation')
    map('gd', '<cmd>Lspsaga goto_definition<cr>', 'Goto Definition')
    map('gp', '<cmd>Lspsaga peek_definition<cr>', 'Peek Definition')
    map('gr', '<cmd>Lspsaga finder<cr>', 'Find References')
    map('gI', '<cmd>Lspsaga finder imp<cr>', 'Find Implementation')
    map('gD', vim.lsp.buf.declaration, 'Goto Declaration')

    -- Lspsaga diagnostics
    map('[d', '<cmd>Lspsaga diagnostic_jump_prev<cr>', 'Prev Diagnostic')
    map(']d', '<cmd>Lspsaga diagnostic_jump_next<cr>', 'Next Diagnostic')
    map('<leader>e', '<cmd>Lspsaga show_line_diagnostics<cr>', 'Line Diagnostics')

    -- Lspsaga code actions and rename
    map('<leader>ca', '<cmd>Lspsaga code_action<cr>', 'Code Action')
    map('<leader>rn', '<cmd>Lspsaga rename<cr>', 'Rename')

    -- Lspsaga outline
    map('<leader>o', '<cmd>Lspsaga outline<cr>', 'Toggle Outline')

    -- Lspsaga call hierarchy
    map('<leader>ci', '<cmd>Lspsaga incoming_calls<cr>', 'Incoming Calls')
    map('<leader>co', '<cmd>Lspsaga outgoing_calls<cr>', 'Outgoing Calls')

    -- Mini.pick for symbols
    map('<leader>D', require('mini.pick').builtin.lsp({ scope = 'type_definition' }), 'Type Definition')
    map('<leader>ds', require('mini.pick').builtin.lsp({ scope = 'document_symbol' }), 'Document Symbols')
    map('<leader>ws', require('mini.pick').builtin.lsp({ scope = 'workspace_symbol' }), 'Workspace Symbols')

    -- Workspace folder management
    map('<leader>wa', vim.lsp.buf.add_workspace_folder, 'Workspace Add Folder')
    map('<leader>wr', vim.lsp.buf.remove_workspace_folder, 'Workspace Remove Folder')
    map('<leader>wl', function()
      print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
    end, 'Workspace List Folders')

    -- Format buffer
    map('<leader>cf', function()
      vim.lsp.buf.format({ async = false, timeout_ms = 2000 })
    end, 'Code Format')

    -- Create a command `:Format` local to the LSP buffer
    vim.api.nvim_buf_create_user_command(event.buf, 'Format', function(_)
      vim.lsp.buf.format()
    end, { desc = 'Format current buffer with LSP' })
  end,
})