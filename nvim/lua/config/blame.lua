-- Toggleable inline blame for the current line.
--
-- Shows the change that last touched the cursor line as virtual text at the
-- end of the line, gitsigns-style. The backend is chosen per file: jj when the
-- file lives in a jj repo/workspace (so blame keeps working where there is no
-- `.git`, e.g. a secondary `jj workspace`), otherwise plain git.
--
-- Blame is computed once per buffer (asynchronously) and re-used on cursor
-- movement; it refreshes on write, when line numbers can shift.

local M = {}

local ns = vim.api.nvim_create_namespace('inline_blame')
local augroup = vim.api.nvim_create_augroup('InlineBlame', { clear = true })

-- Per-buffer state, keyed by bufnr:
--   { enabled = bool, lines = { [lnum] = { rev, author, date, summary } } }
local state = {}

-- jj template: change-id, author, date, summary for each line, NUL-delimited,
-- one row per source line so output line N maps to buffer line N.
local JJ_TEMPLATE = table.concat({
  'commit.change_id().shortest(8)',
  'commit.author().name()',
  'commit.author().timestamp().local().format("%Y-%m-%d")',
  'commit.description().first_line()',
}, [[ ++ "\x00" ++ ]]) .. [[ ++ "\n"]]

-- jj is the user's primary VCS and is always installed alongside `.jj`, but
-- probe once (and cache) so detection never assumes a tool that is absent.
local has_jj
local function detect_vcs(file)
  local dir = vim.fs.dirname(file)
  if vim.fs.find('.jj', { path = dir, upward = true, type = 'directory' })[1] then
    if has_jj == nil then has_jj = vim.fn.executable('jj') == 1 end
    if has_jj then return 'jj' end
  end
  if vim.fs.find('.git', { path = dir, upward = true })[1] then
    return 'git'
  end
  return nil
end

local function parse_jj(stdout)
  local lines, n = {}, 0
  for row in vim.gsplit(stdout, '\n', { plain = true }) do
    if row ~= '' then
      n = n + 1
      local f = vim.split(row, '\0', { plain = true })
      lines[n] = { rev = f[1], author = f[2], date = f[3], summary = f[4] or '' }
    end
  end
  return lines
end

local function parse_git(stdout)
  local lines, cur, lnum = {}, nil, nil
  for row in vim.gsplit(stdout, '\n', { plain = true }) do
    local hash, final = row:match('^(%x+)%s+%d+%s+(%d+)')
    if hash and #hash >= 7 then
      lnum = tonumber(final)
      cur = { rev = hash:sub(1, 8) }
    elseif row:sub(1, 1) == '\t' then
      if cur and lnum then lines[lnum] = cur end
      cur = nil
    elseif cur then
      local k, v = row:match('^(%S+) (.*)$')
      if k == 'author' then
        cur.author = v
      elseif k == 'author-time' then
        cur.date = os.date('%Y-%m-%d', tonumber(v))
      elseif k == 'summary' then
        cur.summary = v
      end
    end
  end
  return lines
end

local function render(buf)
  local st = state[buf]
  if not st or not st.enabled then return end
  if vim.api.nvim_get_current_buf() ~= buf then return end
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  if not st.lines then return end
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local info = st.lines[lnum]
  if not info or not info.rev then return end
  local text = string.format('  %s · %s · %s · %s',
    info.rev, info.author or '?', info.date or '', info.summary or '')
  pcall(vim.api.nvim_buf_set_extmark, buf, ns, lnum - 1, 0, {
    virt_text = { { text, 'Comment' } },
    virt_text_pos = 'eol',
    hl_mode = 'combine',
  })
end

local function refresh(buf)
  local st = state[buf]
  if not st or not st.enabled then return end
  local file = vim.api.nvim_buf_get_name(buf)
  if file == '' or vim.fn.filereadable(file) == 0 then return end
  local vcs = detect_vcs(file)
  if not vcs then
    vim.notify('inline blame: not a git or jj repository', vim.log.levels.WARN)
    return
  end
  local cmd = vcs == 'jj'
    and { 'jj', 'file', 'annotate', '--ignore-working-copy', '-T', JJ_TEMPLATE, file }
    or { 'git', 'blame', '--line-porcelain', file }
  vim.system(cmd, { cwd = vim.fs.dirname(file), text = true }, function(res)
    vim.schedule(function()
      local s = state[buf]
      if not s or not s.enabled then return end
      if res.code ~= 0 then
        vim.notify('inline blame failed: ' .. (res.stderr or ''):gsub('%s+$', ''), vim.log.levels.WARN)
        return
      end
      s.lines = vcs == 'jj' and parse_jj(res.stdout) or parse_git(res.stdout)
      render(buf)
    end)
  end)
end

function M.toggle()
  local buf = vim.api.nvim_get_current_buf()
  local st = state[buf]
  if st and st.enabled then
    st.enabled = false
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    vim.api.nvim_clear_autocmds({ group = augroup, buffer = buf })
    vim.notify('inline blame: off')
    return
  end
  state[buf] = { enabled = true }
  -- Update the displayed line on cursor movement (cache lookup + extmark only).
  vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
    group = augroup,
    buffer = buf,
    callback = function() render(buf) end,
  })
  -- Line numbers shift on write, so recompute the blame for the saved file.
  vim.api.nvim_create_autocmd('BufWritePost', {
    group = augroup,
    buffer = buf,
    callback = function() refresh(buf) end,
  })
  vim.api.nvim_create_autocmd({ 'BufWipeout', 'BufDelete' }, {
    group = augroup,
    buffer = buf,
    callback = function() state[buf] = nil end,
  })
  vim.notify('inline blame: on')
  refresh(buf)
end

return M
