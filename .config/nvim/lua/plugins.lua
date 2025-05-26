-- Initialize mini.deps
-- It's automatically initialized if `mini.nvim` is set up,
-- so we can directly use it.
local add = require('mini.deps').add

-- Add plugins
-- mini.nvim modules like mini.hues are part of the main mini.nvim plugin,
-- so no need to add them separately here if mini.nvim is already loaded.

add('RRethy/vim-illuminate')

add({
  source = 'nvim-orgmode/orgmode',
  -- Assuming mini.deps handles dependencies like treesitter if specified in orgmode's setup,
  -- or if orgmode is updated to use package.module notation for dependencies.
  -- For now, we'll keep it simple. Orgmode might need further config after this.
})

add('folke/which-key.nvim')

-- Ensure plugins are setup/loaded.
-- This might be implicitly handled by mini.deps or might need an explicit call.
-- According to mini.nvim docs, `require('mini.deps').setup()` is optional
-- and primarily for setting path.package.
-- Plugins are typically loaded on demand or as configured.
-- We will rely on the default behavior for now.

-- `folke/which-key.nvim` might need its setup function called here
-- or in keymaps.lua after it's loaded.
-- For now, let's assume its config in keymaps.lua (if any) handles this.

-- No need to add folke/tokyonight.nvim as we're switching to mini.hues.
-- No need to add echasnovski/mini.nvim or echasnovski/mini.hues separately
-- as mini.nvim is loaded from init.lua and includes mini.hues.
