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
end

-- Setup treesitter
M.setup_treesitter = function()
  require('nvim-treesitter.configs').setup({
    -- Parsers are managed by Nix - disable auto-installation
    -- This prevents write errors to read-only /nix/store
    auto_install = false,

    -- Parser list is for reference only - actual parsers come from Nix
    -- See modules/neovim.nix for the list of installed parsers
    ensure_installed = {}, -- Empty: parsers provided by Nix

    highlight = {
      enable = true,
      -- Disable for very large files for performance
      disable = function(lang, buf)
        local max_filesize = 100 * 1024 -- 100 KB
        local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(buf))
        if ok and stats and stats.size > max_filesize then
          return true
        end
      end,
    },

    indent = {
      enable = true,
      -- Disable for certain languages if they have issues
      disable = {},
    },

    incremental_selection = {
      enable = true,
      keymaps = {
        init_selection = '<C-space>',
        node_incremental = '<C-space>',
        scope_incremental = false,
        node_decremental = '<bs>',
      },
    },
  })
end

return M
