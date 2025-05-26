-- Keymappings
vim.keymap.set('n', '<Leader>w', '<cmd>write<cr>', { desc = 'Save file' })
vim.keymap.set('n', '<Leader>q', '<cmd>quit<cr>', { desc = 'Quit Neovim' })

-- Setup which-key.nvim
-- This should be called after which-key is loaded.
-- Assuming mini.deps has loaded it by the time this file is required.
local status_ok, which_key = pcall(require, "which-key")
if not status_ok then
  vim.notify("Failed to load which-key", vim.log.levels.WARN)
  return
end

which_key.setup({
  -- your configuration comes here
  -- or leave it empty to use the default settings
  -- refer to the configuration section for more details
})
