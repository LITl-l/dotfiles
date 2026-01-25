-- Plugin configurations

local M = {}

-- Mini.nvim plugins setup
M.setup_mini = function()
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

  -- Mini.files (file explorer)
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

  -- Mini.statusline
  require('mini.statusline').setup({
    use_icons = true,
    set_vim_settings = true,
  })

  -- Mini.tabline
  require('mini.tabline').setup()

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

  -- Mini.sessions
  require('mini.sessions').setup({
    autoread = false,
    autowrite = true,
    directory = vim.fn.stdpath('state') .. '/sessions',
    file = 'session.vim',
  })

  -- Mini.starter
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
end

-- Setup completion
M.setup_completion = function()
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
end

-- Setup fuzzy finder
M.setup_picker = function()
  require('mini.pick').setup()
  require('mini.extra').setup()
end

-- Setup git integration
M.setup_git = function()
  require('mini.git').setup()
  require('mini.diff').setup({
    view = {
      style = 'sign',
      signs = { add = '+', change = '~', delete = '-' },
    },
  })
end

-- Setup color scheme
M.setup_colorscheme = function()
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
  vim.cmd.colorscheme('catppuccin')
end

-- Setup treesitter
-- Note: nvim-treesitter v1.0+ removed the configs module
-- Highlighting and indent are now handled by Neovim's built-in vim.treesitter
-- Parsers are managed by Nix (see modules/neovim.nix)
M.setup_treesitter = function()
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
        -- Enable treesitter-based indentation
        vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
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
end

return M
