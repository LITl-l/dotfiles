-- Utility functions

local M = {}

-- Toggle format on save
M.toggle_format_on_save = function()
  if vim.g.disable_autoformat then
    vim.g.disable_autoformat = false
    print("Enabled format on save")
  else
    vim.g.disable_autoformat = true
    print("Disabled format on save")
  end
end

-- Get highlight groups under cursor
M.get_highlight_under_cursor = function()
  local result = vim.treesitter.get_captures_at_cursor(0)
  print(vim.inspect(result))
end

-- Toggle diagnostics
M.toggle_diagnostics = function()
  local is_disabled = vim.diagnostic.is_disabled()
  if is_disabled then
    vim.diagnostic.enable()
    print("Enabled diagnostics")
  else
    vim.diagnostic.disable()
    print("Disabled diagnostics")
  end
end

-- Smart quit - close buffer or window
M.smart_quit = function()
  local bufnr = vim.api.nvim_get_current_buf()
  local buf_windows = vim.call("win_findbuf", bufnr)
  local modified = vim.api.nvim_buf_get_option(bufnr, "modified")
  if modified then
    print("Buffer has unsaved changes. Save with :w or force quit with :q!")
    return
  end
  -- If buffer is displayed in multiple windows, close current window
  if #buf_windows > 1 then
    vim.cmd("close")
  else
    vim.cmd("bdelete")
  end
end

-- Create a floating terminal
M.floating_terminal = function(cmd, opts)
  opts = opts or {}
  local width = opts.width or math.floor(vim.o.columns * 0.8)
  local height = opts.height or math.floor(vim.o.lines * 0.8)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
  })

  vim.fn.termopen(cmd or vim.o.shell, { cwd = opts.cwd })
  vim.cmd("startinsert")

  -- Close with escape
  vim.keymap.set("n", "<Esc>", "<cmd>close<cr>", { buffer = buf })
  vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n><cmd>close<cr>", { buffer = buf })

  return buf, win
end

-- Get project root
M.get_root = function()
  local path = vim.api.nvim_buf_get_name(0)
  path = path ~= "" and vim.loop.fs_realpath(path) or vim.loop.cwd()
  local root_patterns = { ".git", "lua", "package.json", "Cargo.toml", "pyproject.toml" }
  return vim.fs.find(root_patterns, { path = path, upward = true })[1] or vim.loop.cwd()
end

-- Run command in project root
M.run_in_root = function(cmd)
  local root = M.get_root()
  local original_cwd = vim.loop.cwd()
  vim.cmd("cd " .. root)
  local result = vim.fn.system(cmd)
  vim.cmd("cd " .. original_cwd)
  return result
end

return M