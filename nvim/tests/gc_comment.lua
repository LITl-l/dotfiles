-- gc/gcc comment and uncomment, using the buffer's own 'commentstring'.
--
-- Commenting used to come from mini.comment, which was removed as a duplicate
-- of what Neovim has shipped since 0.10. Nothing in the config mentions gc any
-- more, so without this the maps could stop working -- a cleared default, a
-- plugin that claims gc and does nothing -- and the only symptom would be a key
-- that no longer comments. The drills in nvim/lua/tutor/drills.lua pin gc and
-- gcc, but a pin only proves a mapping exists, not that it comments.
--
-- Runs on a freshly started editor: the editing plugins load on InsertEnter and
-- BufReadPre, so nothing here is warmed and these are Neovim's own maps.

local function press(keys)
  local ok, err = pcall(vim.api.nvim_feedkeys, vim.keycode(keys), 'xt', false)
  assert(ok, 'pressing ' .. keys .. ' errored: ' .. tostring(err))
end

local function scratch(filetype, lines)
  local buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_set_current_buf(buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype = filetype
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  return buf
end

local function lines_of(buf)
  return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
end

local function assert_lines(buf, expected, label)
  local got = lines_of(buf)
  assert(vim.deep_equal(got, expected),
    label .. ': got ' .. vim.inspect(got) .. ', expected ' .. vim.inspect(expected))
end

for _, lhs in ipairs({ 'gc', 'gcc' }) do
  local m = vim.fn.maparg(lhs, 'n', false, true)
  assert(type(m) == 'table' and not vim.tbl_isempty(m),
    lhs .. ' is not mapped in normal mode')
end

-- Toggle: the same keys must undo themselves.
local buf = scratch('lua', { 'local debug = true' })
press('gcc')
assert_lines(buf, { '-- local debug = true' }, 'gcc must comment a lua line')
press('gcc')
assert_lines(buf, { 'local debug = true' }, 'gcc must uncomment the line it commented')

-- gc takes a motion.
buf = scratch('lua', { 'local a = 1', 'local b = 2', 'local c = 3' })
press('gcj')
assert_lines(buf, { '-- local a = 1', '-- local b = 2', 'local c = 3' },
  'gcj must comment this line and the next')

-- Visual selection.
buf = scratch('lua', { 'local a = 1', 'local b = 2' })
press('Vjgc')
assert_lines(buf, { '-- local a = 1', '-- local b = 2' },
  'gc must comment a visual selection')

-- The delimiter comes from the buffer, not from a hardcoded '--'.
buf = scratch('sh', { 'echo hi' })
press('gcc')
assert_lines(buf, { '# echo hi' }, "gcc must use the buffer's 'commentstring'")

print('gc commenting: ok')
