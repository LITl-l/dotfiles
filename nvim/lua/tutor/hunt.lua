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

-- Does an LSP response point at `target_path`? Pure, so the four result shapes
-- can be pinned without a server: Location{uri}, LocationLink{targetUri},
-- SymbolInformation{location={uri}}, and WorkspaceSymbol, whose `location` may
-- be a bare {uri} with no range.
function M.answer_reaches(responses, target_path)
  target_path = vim.fs.normalize(target_path)
  for _, r in pairs(responses or {}) do
    for _, item in ipairs(r.result or {}) do
      local uri = item.targetUri or item.uri or (item.location and item.location.uri)
      if uri and vim.fs.normalize(vim.uri_to_fname(uri)) == target_path then
        return true
      end
    end
  end
  return false
end

-- Attachment is not readiness, and neither is a reply. Both were measured here:
--
--   * vtsls attaches in about a second, but for the first several seconds a
--     definition request at api/handler.ts answers with the LOCAL import
--     specifier -- same file, line 1 -- and only resolves across the file
--     boundary to auth/session.ts at roughly t+8s;
--   * a definition request at a DECLARATION (store/iface.ts) answers instantly
--     with itself, while the implementation index behind `gI` is still cold.
--
-- Either satisfies "the server responded" while the hunt is still unwinnable,
-- so readiness is defined as the server answering THIS hunt's own request with
-- THIS hunt's own target. That is also the solvability check hunts otherwise
-- lack: drills replay their solution against the target text, and a hunt has no
-- target text to replay against.
function M.await_lsp(buf, timeout_ms, opts)
  opts = opts or {}
  local probe, target = opts.probe, opts.target
  assert(probe and probe.method, 'await_lsp: a probe method is required')
  assert(target, 'await_lsp: a target path is required')

  local deadline = (vim.uv or vim.loop).now() + (timeout_ms or 30000)
  local function remaining()
    return math.max(0, deadline - (vim.uv or vim.loop).now())
  end

  if not vim.wait(remaining(), function()
        return #vim.lsp.get_clients({ bufnr = buf }) > 0
      end, 100) then
    return false
  end

  return vim.wait(remaining(), function()
    local params
    if probe.method == 'workspace/symbol' then
      params = { query = probe.query or '' }
    else
      params = vim.lsp.util.make_position_params(0, 'utf-16')
      if probe.context then
        params.context = probe.context
      end
    end
    return M.answer_reaches(vim.lsp.buf_request_sync(buf, probe.method, params, 2000), target)
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

  if h.needs_lsp and not M.await_lsp(buf, opts.lsp_timeout,
        { probe = h.probe, target = tpath }) then
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
