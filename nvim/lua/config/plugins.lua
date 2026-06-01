-- Plugin configurations

local M = {}

local loaded = {}

local function setup_once(name, callback)
  if loaded[name] then return end
  loaded[name] = true
  callback()
end

local function packadd(name)
  pcall(vim.cmd, 'packadd ' .. name)
end

-- Core mini.nvim plugins needed during startup
M.setup_core = function()
  setup_once('core', function()
    -- Mini.basics
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

    -- Mini.statusline
    require('mini.statusline').setup({
      use_icons = true,
      set_vim_settings = true,
    })

    -- Mini.tabline
    require('mini.tabline').setup()
  end)
end

-- Mini.files (file explorer)
M.setup_files = function()
  setup_once('files', function()
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
  end)
end

M.open_files = function(path)
  M.setup_files()
  if path == '' then
    path = nil
  end
  MiniFiles.open(path)
end

-- Editing helpers that are useful for real buffers, but not needed for first paint
M.setup_editing = function()
  setup_once('editing', function()
    -- Mini.comment
    require('mini.comment').setup()

    -- Mini.surround
    require('mini.surround').setup()

    -- Mini.pairs
    require('mini.pairs').setup()

    -- Mini.ai (better text objects)
    require('mini.ai').setup()

    -- Mini.splitjoin
    require('mini.splitjoin').setup()

    -- Mini.indentscope
    require('mini.indentscope').setup({
      symbol = '│',
      draw = {
        delay = 100,
        animation = require('mini.indentscope').gen_animation.none(),
      },
    })

    -- Mini.hipatterns
    require('mini.hipatterns').setup({
      highlighters = {
        fixme = { pattern = '%f[%w]()FIXME()%f[%W]', group = 'MiniHipatternsFixme' },
        hack  = { pattern = '%f[%w]()HACK()%f[%W]',  group = 'MiniHipatternsHack'  },
        todo  = { pattern = '%f[%w]()TODO()%f[%W]',  group = 'MiniHipatternsTodo'  },
        note  = { pattern = '%f[%w]()NOTE()%f[%W]',  group = 'MiniHipatternsNote'  },
      },
    })

    -- Mini.trailspace
    require('mini.trailspace').setup()
  end)
end

-- Setup completion
M.setup_completion = function()
  setup_once('completion', function()
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
  end)
end

-- Setup fuzzy finder
M.setup_picker = function()
  setup_once('picker', function()
    require('mini.pick').setup()
    require('mini.extra').setup()
  end)
end

M.pick = function(source)
  M.setup_picker()
  vim.cmd('Pick ' .. source)
end

M.pick_colorschemes = function()
  M.setup_picker()
  require('mini.extra').pickers.colorschemes()
end

M.pick_lsp = function(scope)
  M.setup_picker()
  require('mini.extra').pickers.lsp({ scope = scope })
end

-- Setup git integration
M.setup_git = function()
  setup_once('git', function()
    require('mini.git').setup()
    require('mini.diff').setup({
      view = {
        style = 'sign',
        signs = { add = '+', change = '~', delete = '-' },
      },
    })
  end)
end

-- Setup Catppuccin only when it is selected
M.setup_catppuccin = function()
  setup_once('catppuccin', function()
    packadd('catppuccin-nvim')
    require('catppuccin').setup({
      flavour = 'latte',
      transparent_background = false,
      term_colors = true,
      color_overrides = {
        latte = {
          -- Base colors matching Wezterm warm palette
          base = '#fefdf8',      -- soft warm white background
          mantle = '#faf8f3',    -- very light warm white
          crust = '#f5ede3',     -- cream

          -- Text colors
          text = '#5c4d3d',      -- warm brown foreground
          subtext1 = '#6d5d4d',  -- slightly lighter brown
          subtext0 = '#8b7355',  -- medium brown

          -- Overlay colors
          overlay2 = '#a89888',  -- light brown
          overlay1 = '#c5b5a5',  -- lighter brown
          overlay0 = '#e6d5c3',  -- light tan

          -- Surface colors
          surface2 = '#f5e6d3',  -- light beige (selection)
          surface1 = '#f5ede3',  -- cream
          surface0 = '#faf8f3',  -- very light warm white

          -- Accent colors from warm palette
          blue = '#7c8fa3',      -- muted slate
          lavender = '#97aec2',  -- light slate
          sapphire = '#8ea59d',  -- sage
          sky = '#abd5c9',       -- mint
          teal = '#8ea59d',      -- sage cyan
          green = '#8a9a5b',     -- olive
          yellow = '#d99545',    -- amber
          peach = '#d97742',     -- warm orange (primary accent)
          maroon = '#c04f30',    -- terracotta
          red = '#c04f30',       -- terracotta red
          mauve = '#a06469',     -- dusty rose
          pink = '#b88b8f',      -- rose
          flamingo = '#b88b8f',  -- rose
          rosewater = '#d97742', -- warm orange
        },
      },
      integrations = {
        mini = {
          enabled = true,
          indentscope_color = '',
        },
      },
    })
  end)
end

M.apply_colorscheme = function(name)
  if name == 'catppuccin' then
    M.setup_catppuccin()
  end
  vim.cmd.colorscheme(name)
end

-- Setup color scheme
M.setup_colorscheme = function()
  setup_once('colorscheme', function()
    -- Active scheme: monochrome-light-cool-gray (see nvim/colors/).
    -- Catppuccin is configured lazily only when selected.
    M.apply_colorscheme('monochrome-light-cool-gray')

    -- Cycle through the curated colorscheme list with <leader>uc.
    local schemes = {
      'monochrome-light-cool-gray',
      'monochrome-dark-cool-gray',
      'catppuccin',
    }
    vim.keymap.set('n', '<leader>uc', function()
      local current = vim.g.colors_name
      local next_idx = 1
      for i, s in ipairs(schemes) do
        if s == current then
          next_idx = (i % #schemes) + 1
          break
        end
      end
      M.apply_colorscheme(schemes[next_idx])
      vim.notify('colorscheme: ' .. schemes[next_idx])
    end, { desc = 'Cycle colorscheme' })
  end)
end

-- Setup treesitter
-- Note: nvim-treesitter v1.0+ removed the configs module
-- Highlighting and indent are now handled by Neovim's built-in vim.treesitter
-- Parsers are managed by Nix (see modules/neovim.nix)
M.setup_treesitter = function()
  setup_once('treesitter', function()
    -- Enable treesitter-based highlighting for all supported filetypes
    vim.api.nvim_create_autocmd('FileType', {
      callback = function(args)
        -- Skip for very large files (100KB+)
        local max_filesize = 100 * 1024
        local ok, stats = pcall(vim.uv.fs_stat, vim.api.nvim_buf_get_name(args.buf))
        if ok and stats and stats.size > max_filesize then
          return
        end

        -- Start treesitter highlighting if parser is available
        local lang = vim.treesitter.language.get_lang(args.match)
        if lang and pcall(vim.treesitter.start, args.buf, lang) then
          -- Enable treesitter-based indentation and cheap, opt-in folds.
          vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"

          for _, win in ipairs(vim.fn.win_findbuf(args.buf)) do
            vim.api.nvim_set_option_value('foldmethod', 'expr', { win = win })
            vim.api.nvim_set_option_value('foldexpr', 'v:lua.vim.treesitter.foldexpr()', { win = win })
            vim.api.nvim_set_option_value('foldtext', '', { win = win })
            vim.api.nvim_set_option_value('foldlevel', 99, { win = win })
            vim.api.nvim_set_option_value('foldenable', false, { win = win })
          end
        end
      end,
    })

    -- Incremental selection using built-in vim.treesitter API
    -- (nvim-treesitter v1.0+ removed the incremental_selection module)
    local selection_stack = {}

    local function select_node(node)
      if not node then return end
      local start_row, start_col, end_row, end_col = node:range()
      vim.api.nvim_buf_set_mark(0, '<', start_row + 1, start_col, {})
      vim.api.nvim_buf_set_mark(0, '>', end_row + 1, end_col - 1, {})
      vim.cmd('normal! gv')
    end

    local function init_selection()
      selection_stack = {}
      local node = vim.treesitter.get_node()
      if node then
        table.insert(selection_stack, node)
        select_node(node)
      end
    end

    local function node_incremental()
      local node = selection_stack[#selection_stack]
      if not node then
        node = vim.treesitter.get_node()
      end
      if node then
        local parent = node:parent()
        if parent then
          table.insert(selection_stack, parent)
          select_node(parent)
        end
      end
    end

    local function node_decremental()
      if #selection_stack > 1 then
        table.remove(selection_stack)
        select_node(selection_stack[#selection_stack])
      end
    end

    vim.keymap.set('n', '<C-space>', init_selection, { desc = 'Start incremental selection' })
    vim.keymap.set('x', '<C-space>', node_incremental, { desc = 'Increment selection to node' })
    vim.keymap.set('x', '<bs>', node_decremental, { desc = 'Decrement selection to node' })
  end)
end

-- Setup lspsaga
M.setup_lspsaga = function()
  setup_once('lspsaga', function()
    packadd('lspsaga.nvim')
    require('lspsaga').setup({
      ui = {
        border = 'rounded',
        code_action = '󰌵',
      },
      lightbulb = {
        enable = false,
      },
      symbol_in_winbar = {
        enable = false,
      },
      outline = {
        layout = 'float',
      },
    })
  end)
end

-- Setup LSP
M.setup_lsp = function()
  setup_once('lsp', function()
    packadd('nvim-lspconfig')
    M.setup_lspsaga()
    require('config.lsp').setup()
  end)
end

-- Setup formatter
M.setup_format = function()
  setup_once('format', function()
    packadd('conform.nvim')
    require('config.format').setup()
  end)
end

-- Setup DAP
M.setup_dap = function()
  setup_once('dap', function()
    packadd('nvim-nio')
    packadd('nvim-dap')
    packadd('nvim-dap-ui')
    packadd('nvim-dap-virtual-text')
    require('config.dap').setup()
  end)
end

-- Setup which-key
M.setup_whichkey = function()
  setup_once('whichkey', function()
    packadd('which-key.nvim')
    local wk = require('which-key')
    wk.setup({
      preset = 'modern',
      delay = 300,
      icons = {
        mappings = false,
        rules = false,
      },
      spec = {
        { '<leader>b', group = 'buffer' },
        { '<leader>c', group = 'code' },
        { '<leader>d', group = 'debug' },
        { '<leader>f', group = 'find' },
        { '<leader>g', group = 'git' },
        { '<leader>s', group = 'search' },
        { '<leader>u', group = 'ui/toggle' },
        { '<leader>w', group = 'window' },
        { '<leader><tab>', group = 'tab' },
      },
    })
  end)
end

return M
