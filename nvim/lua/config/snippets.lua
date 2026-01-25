-- Snippet configuration using LuaSnip
-- Provides snippet expansion and friendly-snippets collection

local M = {}

M.setup = function()
  local ok, luasnip = pcall(require, 'luasnip')
  if not ok then
    return
  end

  -- Load friendly-snippets
  require('luasnip.loaders.from_vscode').lazy_load()

  -- Snippet settings
  luasnip.config.set_config({
    history = true,
    updateevents = 'TextChanged,TextChangedI',
    enable_autosnippets = true,
  })

  -- Keymaps for snippet navigation
  vim.keymap.set({ 'i', 's' }, '<C-k>', function()
    if luasnip.expand_or_jumpable() then
      luasnip.expand_or_jump()
    end
  end, { silent = true, desc = 'Expand or jump to next snippet' })

  vim.keymap.set({ 'i', 's' }, '<C-j>', function()
    if luasnip.jumpable(-1) then
      luasnip.jump(-1)
    end
  end, { silent = true, desc = 'Jump to previous snippet' })

  vim.keymap.set({ 'i', 's' }, '<C-l>', function()
    if luasnip.choice_active() then
      luasnip.change_choice(1)
    end
  end, { silent = true, desc = 'Cycle through choices' })

  -- Custom snippets can be added here
  local s = luasnip.snippet
  local t = luasnip.text_node
  local i = luasnip.insert_node

  -- Lua snippets
  luasnip.add_snippets('lua', {
    s('fn', {
      t('function '), i(1, 'name'), t('('), i(2), t({ ')', '  ' }),
      i(0),
      t({ '', 'end' }),
    }),
    s('lfn', {
      t('local function '), i(1, 'name'), t('('), i(2), t({ ')', '  ' }),
      i(0),
      t({ '', 'end' }),
    }),
  })

  -- Nix snippets
  luasnip.add_snippets('nix', {
    s('let', {
      t({ 'let', '  ' }), i(1, 'name'), t(' = '), i(2, 'value'), t({ ';', 'in' }),
      t({ '', '' }), i(0),
    }),
    s('pkg', {
      t('{ pkgs, ... }:'), t({ '', '', '{', '  ' }),
      i(0),
      t({ '', '}' }),
    }),
  })
end

return M
