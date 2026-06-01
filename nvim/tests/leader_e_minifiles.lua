local plugins = require('config.plugins')

assert(type(plugins.open_files) == 'function', 'config.plugins.open_files must exist')

local function assert_open_files_loads_minifiles()
  local ok, err = pcall(function()
    plugins.open_files()
  end)

  assert(ok, 'config.plugins.open_files() errored: ' .. tostring(err))
  assert(_G.MiniFiles and type(MiniFiles.open) == 'function', 'MiniFiles.open was not loaded')

  if type(MiniFiles.close) == 'function' then
    pcall(MiniFiles.close)
  end
end

local function assert_map_invokes_file_explorer(lhs, expected_path, label)
  local call = { seen = false, path = nil }
  local original = plugins.open_files

  plugins.open_files = function(path)
    call.seen = true
    call.path = path
  end

  local ok, err = pcall(function()
    vim.api.nvim_feedkeys(vim.keycode(lhs), 'xt', false)
  end)

  plugins.open_files = original

  assert(ok, label .. ': pressing ' .. lhs .. ' errored: ' .. tostring(err))
  assert(call.seen, label .. ': ' .. lhs .. ' did not invoke config.plugins.open_files(); effective map = ' .. vim.inspect(vim.fn.maparg(lhs, 'n', false, true)))
  assert(call.path == expected_path, label .. ': ' .. lhs .. ' passed path ' .. vim.inspect(call.path) .. ', expected ' .. vim.inspect(expected_path))
end

local function assert_file_explorer_maps(label)
  assert_map_invokes_file_explorer('<leader>e', nil, label)
  assert_map_invokes_file_explorer('<leader>E', vim.api.nvim_buf_get_name(0), label)
end

assert_open_files_loads_minifiles()
assert_file_explorer_maps('startup')

local buf = vim.api.nvim_create_buf(true, false)
vim.api.nvim_set_current_buf(buf)
vim.api.nvim_exec_autocmds('LspAttach', {
  buffer = buf,
  data = { client_id = 1 },
})

assert_file_explorer_maps('after LspAttach')
