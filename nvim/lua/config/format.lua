-- Formatter configuration using conform.nvim
-- Provides unified formatting across different file types

local M = {}

M.setup = function()
  local ok, conform = pcall(require, 'conform')
  if not ok then
    return
  end

  conform.setup({
    -- Formatters by filetype
    formatters_by_ft = {
      -- Lua
      lua = { 'stylua' },

      -- Nix
      nix = { 'nixpkgs_fmt' },

      -- Shell
      sh = { 'shfmt' },
      bash = { 'shfmt' },
      zsh = { 'shfmt' },
      fish = { 'fish_indent' },

      -- Python
      python = { 'black' },

      -- Rust
      rust = { 'rustfmt' },

      -- Go
      go = { 'gofmt', 'goimports' },

      -- JavaScript/TypeScript
      javascript = { 'prettier' },
      typescript = { 'prettier' },
      javascriptreact = { 'prettier' },
      typescriptreact = { 'prettier' },

      -- Web
      html = { 'prettier' },
      css = { 'prettier' },
      scss = { 'prettier' },
      json = { 'prettier' },
      jsonc = { 'prettier' },
      yaml = { 'prettier' },
      markdown = { 'prettier' },

      -- Fallback
      ['_'] = { 'trim_whitespace' },
    },

    -- Format on save
    format_on_save = function(bufnr)
      -- Disable with a global or buffer-local variable
      if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
        return
      end
      return {
        timeout_ms = 2000,
        lsp_fallback = true,
      }
    end,

    -- Notify on format errors
    notify_on_error = true,
  })

  -- Create Format command
  vim.api.nvim_create_user_command('Format', function(args)
    local range = nil
    if args.count ~= -1 then
      local end_line = vim.api.nvim_buf_get_lines(0, args.line2 - 1, args.line2, true)[1]
      range = {
        start = { args.line1, 0 },
        ['end'] = { args.line2, end_line:len() },
      }
    end
    conform.format({ async = true, lsp_fallback = true, range = range })
  end, { range = true, desc = 'Format buffer or range' })

  -- Create FormatDisable command
  vim.api.nvim_create_user_command('FormatDisable', function(args)
    if args.bang then
      -- FormatDisable! will disable formatting globally
      vim.g.disable_autoformat = true
    else
      vim.b.disable_autoformat = true
    end
    vim.notify('Format on save disabled', vim.log.levels.INFO)
  end, { desc = 'Disable autoformat-on-save', bang = true })

  -- Create FormatEnable command
  vim.api.nvim_create_user_command('FormatEnable', function()
    vim.b.disable_autoformat = false
    vim.g.disable_autoformat = false
    vim.notify('Format on save enabled', vim.log.levels.INFO)
  end, { desc = 'Re-enable autoformat-on-save' })

  -- Keymap for manual formatting
  vim.keymap.set({ 'n', 'v' }, '<leader>cf', function()
    conform.format({ async = true, lsp_fallback = true })
  end, { desc = '[C]ode [F]ormat' })
end

return M
