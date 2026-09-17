-- Hunt lifecycle: cross-file LSP navigation over the committed fixture.
--
-- A sibling of session.lua, not an extension of it. Three of session.lua's
-- invariants are load-bearing there and wrong here:
--   * its buffer is a scratch buffer (nvim_create_buf(false, true)) -- unlisted,
--     'nofile', no path -- so no language server can attach and gd/gr have
--     nothing to resolve;
--   * its predicate compares buffer TEXT on TextChanged, and a hunt changes no
--     text at all: it moves a cursor;
--   * its autocmd is scoped to that one buffer, and a hunt succeeds by LEAVING
--     its start buffer, so a buffer-scoped trigger could never fire at the
--     target.
--
-- Scoring is SHARED, deliberately: session.score and progress.record are reused
-- verbatim, so a hunt's ratio, verdict tier and spaced-repetition rank mean the
-- same thing as a drill's. Ids are namespaced 'hunt:' in the progress file.

local hunts = require('tutor.hunts')
local progress = require('tutor.progress')
local session = require('tutor.session')

local M = {}

local current = nil
local ns = vim.api.nvim_create_namespace('tutor_hunt')

function M.active()
  return current
end

-- True for any buffer inside the fixture tree. A hunt is free-route: gd can
-- land the user in the decoy and gr in any caller, so "a buffer this hunt is
-- responsible for" cannot be a list captured up front.
function M.is_fixture_buf(buf)
  local name = vim.api.nvim_buf_get_name(buf)
  if name == '' then
    return false
  end
  local root = hunts.root()
  name = vim.fs.normalize(name)
  return name:sub(1, #root + 1) == root .. '/'
end

-- Attachment is not readiness. Measured on this machine, vtsls attaches in
-- about a second but answers a definition request only after roughly 8s of
-- indexing. Starting the keystroke clock at attach would charge the user for
-- the server's cold start, so wait for a real answer instead of for a client.
--
-- The probe asks for a definition AT THE CURSOR, which is why hunts.lua pins a
-- `word` on every start: on whitespace the server correctly returns nothing and
-- this would wait out its whole timeout.
function M.await_lsp(buf, timeout_ms)
  timeout_ms = timeout_ms or 30000
  local attached = vim.wait(timeout_ms, function()
    return #vim.lsp.get_clients({ bufnr = buf }) > 0
  end, 100)
  if not attached then
    return false
  end
  return vim.wait(timeout_ms, function()
    local params = vim.lsp.util.make_position_params(0, 'utf-16')
    local res = vim.lsp.buf_request_sync(buf, 'textDocument/definition', params, 1000)
    if not res then
      return false
    end
    for _, r in pairs(res) do
      if r.result and #r.result > 0 then
        return true
      end
    end
    return false
  end, 500)
end

function M.reached(handle)
  local name = vim.api.nvim_buf_get_name(0)
  if name == '' or vim.fs.normalize(name) ~= handle.target_path then
    return false
  end
  return vim.api.nvim_win_get_cursor(0)[1] == handle.target_line
end

-- Ordered to read top-down from the code the user is standing in, like the
-- drill briefing: which hunt this is, where to get to, then what it should cost.
function M.briefing_lines(h, index, total)
  local _, tline = hunts.resolve(h.target)
  return {
    '',
    ('Hunt %d/%d  [%s]  %s'):format(index or 1, total or 1, h.group, h.id),
    '',
    'Goal:',
    '    ' .. h.goal,
    '',
    ('Destination: %s:%d'):format(h.target.file, tline),
    '',
    ('optimal: %d keystrokes     key: %s'):format(h.optimal, h.solution),
    '',
    'Navigate to the destination. The route is free -- only the cost is scored.',
    ':Dojo hunt-skip to move on.',
  }
end

function M.stop(handle)
  handle = handle or current
  if not handle or handle.stopped then
    return
  end
  handle.stopped = true

  if handle.on_key_active then
    pcall(vim.on_key, nil, ns)
    handle.on_key_active = false
  end
  if handle.augroup then
    pcall(vim.api.nvim_del_augroup_by_id, handle.augroup)
    handle.augroup = nil
  end
  if current == handle then
    current = nil
  end
end

function M.start(h, opts)
  opts = opts or {}
  M.stop(current)

  local spath, sline, scol = hunts.resolve(h.start)
  local tpath, tline = hunts.resolve(h.target)

  vim.cmd('edit ' .. vim.fn.fnameescape(spath))
  local buf = vim.api.nvim_get_current_buf()
  vim.bo[buf].modifiable = false

  -- The optimal keystroke count assumes the cursor is already on the symbol.
  local last = vim.api.nvim_buf_line_count(buf)
  pcall(vim.api.nvim_win_set_cursor, 0, { math.min(sline, last), scol })

  local handle = {
    hunt = h,
    buf = buf,
    keys = 0,
    target_path = tpath,
    target_line = tline,
    typed = {},
  }
  -- Published before the readiness wait so that a caller -- and the test that
  -- pins this ordering -- can observe a hunt that exists but is not yet timed.
  current = handle

  if h.needs_lsp and not M.await_lsp(buf, opts.lsp_timeout) then
    vim.notify(
      ('Dojo: no language server answered for %s; skipping this hunt rather than '
        .. 'scoring a route you cannot take'):format(h.start.file),
      vim.log.levels.WARN)
    M.stop(handle)
    return nil
  end

  handle.started_at = (vim.uv or vim.loop).hrtime()

  -- Count only real user keystrokes; `typed` is empty for keys synthesised by a
  -- mapping's RHS, so Lspsaga's <cmd> maps cannot inflate the count.
  vim.on_key(function(_, typed)
    if handle.stopped then
      return
    end
    if typed and typed ~= '' then
      handle.keys = handle.keys + 1
      table.insert(handle.typed, typed)
    end
  end, ns)
  handle.on_key_active = true

  -- GLOBAL, with no `buffer = ...`: the hunt is won by leaving `buf`, so the
  -- trigger has to survive the jump. The augroup is the whole scope, and every
  -- callback guards on handle.stopped.
  handle.augroup = vim.api.nvim_create_augroup('TutorHunt', { clear = true })
  vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI', 'BufEnter', 'WinEnter' }, {
    group = handle.augroup,
    callback = function()
      if handle.stopped then
        return true
      end
      -- gd and gr open fixture files this hunt never named, so freeze them on
      -- arrival rather than only freezing the start buffer.
      local cur = vim.api.nvim_get_current_buf()
      if M.is_fixture_buf(cur) then
        vim.bo[cur].modifiable = false
      end
      if not M.reached(handle) then
        return
      end
      local ms = math.floor(((vim.uv or vim.loop).hrtime() - handle.started_at) / 1e6)
      local score = session.score(handle.keys, h.optimal, ms)
      M.stop(handle)
      pcall(progress.record, 'hunt:' .. h.id, score)
      if opts.on_complete then
        opts.on_complete(score)
      end
      return true
    end,
  })

  return handle
end

return M
