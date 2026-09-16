-- The tutor engine. One mechanism serves both modes: a keystroke stream plus a
-- completion predicate.
--   drill  predicate: scratch buffer lines == target lines
--   lesson predicate: typed keys match the step's expected lhs
--
-- Keystrokes are counted from vim.on_key's `typed` argument, not the resolved
-- keys, so a mapping's right-hand side cannot inflate the count.

local progress = require('tutor.progress')

local M = {}

local current = nil
local ns = vim.api.nvim_create_namespace('tutor_session')

function M.score(counted, optimal, ms)
  local ratio = 1
  if optimal and optimal > 0 then
    ratio = counted / optimal
  end
  return { keys = counted, optimal = optimal or 0, ratio = ratio, ms = ms }
end

function M.active()
  return current
end

local function default_predicate(handle)
  if not vim.api.nvim_buf_is_valid(handle.buf) then
    return false
  end
  local lines = vim.api.nvim_buf_get_lines(handle.buf, 0, -1, false)
  return vim.deep_equal(lines, handle.exercise.after)
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

function M.start(exercise, opts)
  opts = opts or {}
  M.stop(current)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].filetype = exercise.filetype or 'lua'
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, exercise.before)

  local handle = {
    exercise = exercise,
    buf = buf,
    keys = 0,
    started_at = (vim.uv or vim.loop).hrtime(),
    predicate = opts.predicate or default_predicate,
    typed = {},
  }

  -- Count only real user keystrokes. `typed` is empty for keys synthesised by
  -- a mapping's RHS, which is exactly what must not be scored.
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

  handle.augroup = vim.api.nvim_create_augroup('TutorSession', { clear = true })
  vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
    group = handle.augroup,
    buffer = buf,
    callback = function()
      if handle.stopped then
        return true
      end
      -- A drill that changes the line count (gS) would leave the briefing
      -- anchored mid-buffer. ui is only loaded once something has drawn one,
      -- so look it up rather than require it: the engine stays testable with
      -- no window and no rendering modules.
      local ui = package.loaded['tutor.ui']
      if ui then
        ui.reanchor_briefing(buf)
      end
      if not handle.predicate(handle) then
        return
      end
      local ms = math.floor(((vim.uv or vim.loop).hrtime() - handle.started_at) / 1e6)
      local score = M.score(handle.keys, exercise.optimal, ms)
      M.stop(handle)
      if exercise.id then
        pcall(progress.record, exercise.id, score)
      end
      if opts.on_complete then
        opts.on_complete(score)
      end
      return true
    end,
  })

  current = handle
  return handle
end

return M
