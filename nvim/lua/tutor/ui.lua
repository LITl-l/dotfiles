-- Rendering for the tutor. Kept separate from session.lua so the engine can be
-- tested without a window, and so panels can change without touching scoring.

local lessons = require('tutor.lessons')
local drills = require('tutor.drills')
local progress = require('tutor.progress')

local M = {}

local function pad(s, n)
  s = tostring(s)
  return s .. string.rep(' ', math.max(0, n - vim.fn.strdisplaywidth(s)))
end

function M.float(lines, opts)
  opts = opts or {}
  local width = opts.width or math.min(80, math.max(40, math.floor(vim.o.columns * 0.8)))
  local height = opts.height or math.min(#lines + 1, math.max(10, math.floor(vim.o.lines * 0.8)))

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].filetype = 'markdown'

  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = math.max(0, math.floor((vim.o.lines - height) / 2)),
    col = math.max(0, math.floor((vim.o.columns - width) / 2)),
    style = 'minimal',
    border = 'rounded',
    title = opts.title and (' ' .. opts.title .. ' ') or nil,
  })
  vim.wo[win].wrap = true

  for _, key in ipairs({ 'q', '<Esc>' }) do
    vim.keymap.set('n', key, function()
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
    end, { buffer = buf, nowait = true, desc = 'Close tutor' })
  end

  return buf, win
end

function M.lesson_lines()
  local lines = {
    '# Dojo -- this config, keymap by keymap',
    '',
    'Leader is <Space>. Chapters are generated from your live keymaps, so they',
    'cannot drift from the config.',
    '',
  }
  for _, c in ipairs(lessons.chapters()) do
    lines[#lines + 1] = ('## %s  (%d)'):format(c.title, #c.entries)
    lines[#lines + 1] = c.blurb
    lines[#lines + 1] = ''
    if not c.available then
      lines[#lines + 1] = '  ' .. (c.unavailable_reason or 'No maps in this group yet.')
    end
    for _, e in ipairs(c.entries) do
      lines[#lines + 1] = ('  %s %s'):format(pad(e.lhs, 18), e.desc)
    end
    lines[#lines + 1] = ''
  end
  lines[#lines + 1] = 'Drill the editing maps with :Dojo drill  (or <leader>td)'
  return lines
end

function M.render_lessons()
  return M.float(M.lesson_lines(), {
    title = 'Dojo -- lessons',
    height = math.max(10, math.floor(vim.o.lines * 0.8)),
  })
end

-- The briefing renders UNDER the exercise, so it is ordered to read top-down
-- from the code the user is editing: a blank separator, which drill this is,
-- the state to reach, then how to get there.
function M.drill_lines(exercise, index, total)
  local lines = {
    '',
    ('Drill %d/%d  [%s]  %s'):format(index or 1, total or 1, exercise.group, exercise.id),
    '',
    'Target:',
  }
  for _, l in ipairs(exercise.after) do
    lines[#lines + 1] = '    ' .. l
  end
  lines[#lines + 1] = ''
  lines[#lines + 1] = ('optimal: %d keystrokes%s'):format(
    exercise.optimal, exercise.lhs and ('     key: ' .. exercise.lhs) or '')
  if exercise.hint then
    lines[#lines + 1] = exercise.hint
  end
  lines[#lines + 1] = ''
  lines[#lines + 1] = 'Edit the buffer above to match the target.  :Dojo skip to move on.'
  return lines
end

function M.result_lines(exercise, score)
  local verdict
  if score.ratio <= 1 then
    verdict = 'optimal'
  elseif score.ratio <= 1.5 then
    verdict = 'close'
  else
    verdict = 'room to improve'
  end
  return {
    '# ' .. verdict,
    '',
    ('keystrokes : %d   (optimal %d, ratio %.2f)'):format(score.keys, score.optimal, score.ratio),
    ('time       : %.1fs  (%dms)'):format(score.ms / 1000, score.ms),
    '',
    'optimal solution: ' .. (exercise.solution or ''),
    '',
    -- Not <leader>td: that rebuilds a fresh weakest-first queue, which ejects
    -- the user from a group run. :Dojo skip is what advances THIS queue.
    'Next: :Dojo skip      Stats: <leader>ts',
  }
end

function M.render_result(exercise, score)
  return M.float(M.result_lines(exercise, score), { title = 'Dojo -- result' })
end

function M.stats_lines()
  local data = progress.load()
  local lines = {
    '# Dojo -- progress',
    '',
    ('%s %s %s %s'):format(pad('drill', 30), pad('tries', 7), pad('best', 6), 'ratio'),
    string.rep('-', 56),
  }
  local any = false
  for _, e in ipairs(drills.all()) do
    local s = data[e.id]
    if s then
      any = true
      lines[#lines + 1] = ('%s %s %s %.2f'):format(
        pad(e.id, 30), pad(s.attempts, 7), pad(s.best_keys, 6), s.ewma_ratio)
    end
  end
  if not any then
    lines[#lines + 1] = 'No drills attempted yet. Start with :Dojo drill'
  end
  lines[#lines + 1] = ''
  lines[#lines + 1] = 'ratio = keystrokes used / optimal. Lower is faster.'
  lines[#lines + 1] = 'State: ' .. progress.path()
  return lines
end

function M.render_stats()
  return M.float(M.stats_lines(), { title = 'Dojo -- stats' })
end

local briefing_ns = vim.api.nvim_create_namespace('tutor_briefing')
local BRIEFING_ID = 1

-- One drill runs at a time, so a single slot holds everything needed to move
-- the briefing when the exercise changes line count.
local briefing = { buf = nil, virt = nil }

local function briefing_row(buf)
  return math.max(0, vim.api.nvim_buf_line_count(buf) - 1)
end

-- Pin the drill briefing under the exercise as virtual text. Virtual lines are
-- not buffer content, so the completion predicate (buffer lines == target) is
-- unaffected -- unlike putting the target in the buffer itself, which would
-- also shift the absolute line numbers that gg, NG, :N and gcip depend on.
--
-- Anchored BELOW the last exercise line, never above line 1: no window can
-- scroll higher than the first line, so virt_lines_above there reserves no
-- room and nvim draws nothing at all. That is how a briefing can be attached,
-- assert-ably present, and still invisible.
function M.attach_briefing(buf, lines)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  vim.api.nvim_buf_clear_namespace(buf, briefing_ns, 0, -1)
  local virt = {}
  for _, l in ipairs(lines) do
    virt[#virt + 1] = { { l, 'Comment' } }
  end
  briefing.buf, briefing.virt = buf, virt
  vim.api.nvim_buf_set_extmark(buf, briefing_ns, briefing_row(buf), 0, {
    id = BRIEFING_ID,
    virt_lines = virt,
    virt_lines_above = false,
  })
end

-- Keep the briefing under the exercise when the drill changes the line count --
-- gS splits one line into four, which would otherwise strand it mid-buffer.
-- Re-sets the SAME extmark id rather than adding one, and runs from the
-- session's TextChanged handler, so the hot path is two C calls and a compare.
function M.reanchor_briefing(buf)
  if briefing.buf ~= buf or not briefing.virt or not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  local row = briefing_row(buf)
  local at = vim.api.nvim_buf_get_extmark_by_id(buf, briefing_ns, BRIEFING_ID, {})
  if at[1] == row then
    return
  end
  vim.api.nvim_buf_set_extmark(buf, briefing_ns, row, 0, {
    id = BRIEFING_ID,
    virt_lines = briefing.virt,
    virt_lines_above = false,
  })
end

return M
