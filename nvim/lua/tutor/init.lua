-- Public API for the config tutor.
--
-- The command is :Dojo, not :Tutor -- :Tutor is a built-in Neovim command
-- (exists(':Tutor') == 2, from $VIMRUNTIME/plugin/tutor.vim) that opens
-- vimtutor, and shadowing it would break that.

local M = {}

local function mods()
  return {
    drills = require('tutor.drills'),
    session = require('tutor.session'),
    progress = require('tutor.progress'),
    ui = require('tutor.ui'),
  }
end

-- mini.surround / mini.comment / mini.splitjoin are loaded on InsertEnter, so
-- their maps (sa, gcc, gS) do not exist yet if the user has only been in normal
-- mode. Warm them before a drill can pin on them.
local function warm_editing_maps()
  pcall(function() require('config.plugins').setup_editing() end)
end

function M.open()
  mods().ui.render_lessons()
end

function M.stats()
  mods().ui.render_stats()
end

function M.reset()
  local m = mods()
  vim.ui.select({ 'no', 'yes' }, { prompt = 'Reset all Dojo progress?' }, function(choice)
    if choice == 'yes' then
      m.progress.reset()
      vim.notify('Dojo progress reset', vim.log.levels.INFO)
    end
  end)
end

-- Queue state for a multi-exercise drill run.
local queue, queue_index = {}, 0

-- The drill's own tab, plus the window to return to when the set is done. A
-- drill needs full width -- the briefing is as tall as the exercise again --
-- and reusing one window across the queue is what keeps a skip chain from
-- stacking a new pane per exercise.
local drill_win, origin_win = nil, nil

local function show_drill(buf)
  if drill_win and vim.api.nvim_win_is_valid(drill_win) then
    vim.api.nvim_win_set_buf(drill_win, buf)
    vim.api.nvim_set_current_win(drill_win)
    return
  end
  origin_win = vim.api.nvim_get_current_win()
  vim.cmd('tabnew')
  -- The empty buffer tabnew just made is displaced immediately; wipe it with
  -- the same 'bufhidden' the drill buffers use rather than leaking one per tab.
  vim.bo[vim.api.nvim_get_current_buf()].bufhidden = 'wipe'
  drill_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(drill_win, buf)
end

local function close_drill_win()
  if drill_win and vim.api.nvim_win_is_valid(drill_win)
    and #vim.api.nvim_list_tabpages() > 1 then
    -- Last window in its tabpage, so this closes the tab; 'bufhidden' = wipe
    -- takes the drill buffer with it.
    pcall(vim.api.nvim_win_close, drill_win, true)
    if origin_win and vim.api.nvim_win_is_valid(origin_win) then
      pcall(vim.api.nvim_set_current_win, origin_win)
    end
  end
  drill_win, origin_win = nil, nil
end

local function run_next()
  local m = mods()
  queue_index = queue_index + 1
  local exercise = queue[queue_index]
  if not exercise then
    close_drill_win()
    vim.notify('Dojo: drill set complete', vim.log.levels.INFO)
    return
  end

  local handle = m.session.start(exercise, {
    on_complete = function(score)
      vim.schedule(function()
        -- The predicate can fire from TextChangedI, so the drill may complete
        -- while still in insert mode; the result float is not modifiable.
        if vim.fn.mode():sub(1, 1) == 'i' then
          vim.cmd('stopinsert')
        end
        m.ui.render_result(exercise, score)
      end)
    end,
  })

  local briefing = m.ui.drill_lines(exercise, queue_index, #queue)

  show_drill(handle.buf)
  vim.bo[handle.buf].modifiable = true

  -- The optimal keystroke count assumes a starting cursor position, so place it.
  local cur = exercise.cursor or { 1, 0 }
  local line = math.min(cur[1], vim.api.nvim_buf_line_count(handle.buf))
  local col = math.min(cur[2], #(vim.api.nvim_buf_get_lines(handle.buf, line - 1, line, false)[1] or ''))
  pcall(vim.api.nvim_win_set_cursor, 0, { line, col })

  -- Pinned under the exercise, so the target and the hint stay on screen while
  -- editing instead of scrolling out of the message area.
  m.ui.attach_briefing(handle.buf, briefing)
end

function M.drill(group)
  local m = mods()
  warm_editing_maps()

  if group and group ~= '' then
    local set = m.drills.by_group(group)
    if #set == 0 then
      vim.notify(
        ('Dojo: no drills for group %q. Available: %s')
          :format(group, table.concat(m.drills.groups(), ', ')),
        vim.log.levels.WARN)
      return
    end
    queue = set
  else
    queue = m.drills.weakest(10)
  end
  queue_index = 0
  run_next()
end

function M.skip()
  mods().session.stop()
  run_next()
end

function M.complete(arg)
  local out = { 'drill', 'stats', 'reset', 'skip' }
  vim.list_extend(out, require('tutor.drills').groups())
  if not arg or arg == '' then
    return out
  end
  return vim.tbl_filter(function(c) return c:sub(1, #arg) == arg end, out)
end

function M.command(opts)
  local args = (opts and opts.fargs) or {}
  local sub = args[1]
  if not sub or sub == '' then
    return M.open()
  elseif sub == 'drill' then
    return M.drill(args[2])
  elseif sub == 'stats' then
    return M.stats()
  elseif sub == 'reset' then
    return M.reset()
  elseif sub == 'skip' then
    return M.skip()
  end
  vim.notify('Dojo: unknown subcommand ' .. sub, vim.log.levels.WARN)
end

return M
