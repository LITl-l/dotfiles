-- Headless assertions for the :Dojo tutor.
local inv = require('tutor.inventory')

-- Precondition. Everything below inspects a configured editor, so check that
-- the config actually loaded before asserting on its contents. Without this
-- the first failure is a cryptic `normalise(" ff") = " ff"` rather than the
-- real cause: init.lua aborting at `packadd mini.nvim` before config.options
-- runs, which is what happens when mini.nvim is missing (e.g. a sandbox with
-- no network, where the bootstrap clone cannot work).
assert(vim.g.mapleader == ' ', 'precondition failed: config.options should have '
  .. 'set mapleader to <Space>, got ' .. vim.inspect(vim.g.mapleader)
  .. '. A nil leader means init.lua aborted early -- usually mini.nvim missing '
  .. 'from packpath.')
assert(pcall(require, 'mini.deps'), 'precondition failed: mini.nvim must be on '
  .. 'packpath; the plugin keymaps the drills pin come from it')

-- normalise() re-folds an expanded leader. nvim_get_keymap() returns lhs with
-- the leader already expanded to its literal key, so " ff" not "<leader>ff".
assert(inv.normalise(' ff') == '<leader>ff',
  'normalise(" ff") = ' .. tostring(inv.normalise(' ff')))
assert(inv.normalise('gd') == 'gd', 'non-leader lhs must pass through')
assert(inv.normalise(' <Tab>[') == '<leader><Tab>[', 'special keys keep angle notation')

-- Grouping: the "LSP: " desc prefix outranks the lhs prefix.
assert(inv.group_of({ lhs = '<leader>ws', desc = 'LSP: Workspace Symbols' }) == 'lsp',
  '<leader>ws must group as lsp, not windows')
assert(inv.group_of({ lhs = '<leader>wd', desc = 'Delete window' }) == 'windows',
  '<leader>wd must group as windows')
assert(inv.group_of({ lhs = '<leader>w', desc = 'Save file' }) == 'files',
  '<leader>w is a leaf (Save file), not a windows bucket')
assert(inv.group_of({ lhs = '<leader>ff', desc = 'Find files' }) == 'pick')
assert(inv.group_of({ lhs = 'sa', desc = 'Add surrounding' }) == 'surround')

-- Entries from the live config
local entries = inv.entries()
assert(#entries > 50, 'expected >50 described maps, got ' .. #entries)
for _, e in ipairs(entries) do
  assert(e.desc ~= nil and e.desc ~= '', 'entry with empty desc: ' .. e.lhs)
  assert(not e.lhs:match('^<Plug>'), 'Plug map leaked into inventory: ' .. e.lhs)
  assert(e.group, 'entry without group: ' .. e.lhs)
end

-- No duplicate lhs (the vim.list_extend trap)
local seen = {}
for _, e in ipairs(entries) do
  assert(not seen[e.lhs], 'duplicate lhs in inventory: ' .. e.lhs)
  seen[e.lhs] = true
end

print('tutor.inventory: ok (' .. #entries .. ' entries)')

-- Buffer-local coverage: before LspAttach the lsp group is absent; after, it
-- contains the LSP maps. This is the canary for the whole buffer-local class.
assert(not inv.lsp_available(), 'lsp group must be unavailable before LspAttach')

local buf = vim.api.nvim_create_buf(true, false)
vim.api.nvim_set_current_buf(buf)
vim.api.nvim_exec_autocmds('LspAttach', { buffer = buf, data = { client_id = 1 } })

assert(inv.lsp_available(), 'lsp group must be populated after LspAttach')
local lsp = inv.groups().lsp
local by_lhs = {}
for _, e in ipairs(lsp) do by_lhs[e.lhs] = e end
for _, want in ipairs({ 'gd', 'K', '<leader>rn' }) do
  assert(by_lhs[want], 'lsp group missing ' .. want)
end
-- buffer-local wins the collision: gp is 'Paste from system clipboard' globally
assert(by_lhs['gp'] and by_lhs['gp'].desc:match('^LSP: '),
  'buffer-local must win the gp collision')

print('tutor.inventory buffer-local: ok (' .. #lsp .. ' lsp maps)')

local progress = require('tutor.progress')

-- State must live under stdpath('state'), never inside the read-only nvim/ dir.
assert(progress.path():find(vim.fn.stdpath('state'), 1, true) == 1,
  'progress path must be under stdpath("state"), got ' .. progress.path())

-- A missing or corrupt file degrades to an empty table rather than erroring.
vim.fn.delete(progress.path())
assert(vim.tbl_isempty(progress.load()), 'missing file must load as empty')
vim.fn.mkdir(vim.fs.dirname(progress.path()), 'p')
vim.fn.writefile({ 'this is not json{' }, progress.path())
assert(vim.tbl_isempty(progress.load()), 'corrupt file must load as empty')

-- Round-trip
vim.fn.delete(progress.path())
local stat = progress.record('drill-x', { keys = 8, optimal = 4, ms = 3000 })
assert(stat.attempts == 1 and stat.best_keys == 8, vim.inspect(stat))
assert(math.abs(stat.ewma_ratio - 2.0) < 1e-9, 'first ratio is the raw ratio')
progress.record('drill-x', { keys = 4, optimal = 4, ms = 1200 })
local reloaded = progress.load()['drill-x']
assert(reloaded.attempts == 2, 'attempts must persist')
assert(reloaded.best_keys == 4 and reloaded.best_ms == 1200, 'bests must improve')
assert(reloaded.ewma_ratio < 2.0, 'ewma must move toward the better ratio')

-- Ranking: unseen first, then worse ratio first.
local now = 1757000000
assert(progress.weakness(nil, now) == math.huge, 'unseen must rank first')
local worse = { attempts = 1, ewma_ratio = 3.0, last_seen = now }
local better = { attempts = 1, ewma_ratio = 1.1, last_seen = now }
assert(progress.weakness(worse, now) > progress.weakness(better, now))

vim.fn.delete(progress.path())
print('tutor.progress: ok')

local session = require('tutor.session')

-- Scoring arithmetic
local s = session.score(8, 4, 2500)
assert(s.keys == 8 and s.optimal == 4 and s.ms == 2500, vim.inspect(s))
assert(math.abs(s.ratio - 2.0) < 1e-9, 'ratio = keys / optimal')
-- Beating the authored optimal is surfaced, not clamped.
assert(session.score(3, 4, 100).ratio < 1, 'ratio below 1 must not be clamped')
assert(session.score(5, 0, 100).ratio == 1, 'optimal 0 must not divide by zero')

-- A synthetic exercise completes when the buffer matches the target.
local ex = {
  id = 'synthetic',
  lhs = 'sa',
  before = { 'hello' },
  after = { '"hello"' },
  optimal = 5,
  solution = 'sa iw "',
}
local completed
local handle = session.start(ex, { on_complete = function(sc) completed = sc end })
assert(session.active() == handle, 'session must register as active')
assert(vim.api.nvim_buf_get_lines(handle.buf, 0, -1, false)[1] == 'hello',
  'buffer must be seeded with `before`')

-- Drive the buffer to the target state; the TextChanged predicate fires.
vim.api.nvim_buf_set_lines(handle.buf, 0, -1, false, { '"hello"' })
vim.api.nvim_exec_autocmds('TextChanged', { buffer = handle.buf })

assert(completed, 'on_complete must fire when buffer matches target')
assert(completed.optimal == 5, vim.inspect(completed))
assert(session.active() == nil, 'session must clear itself after completion')

-- Teardown must not leak the on_key handler.
assert(not handle.on_key_active, 'on_key must be unregistered after completion')
session.stop(handle)  -- idempotent

require('tutor.progress').reset()
print('tutor.session: ok')

local drills = require('tutor.drills')

-- mini.surround/comment/splitjoin are InsertEnter-gated, so their maps do not
-- exist until the editing modules are warmed. The tutor does the same before
-- starting a drill.
require('config.plugins').setup_editing()

assert(#drills.all() >= 18, 'expected >=18 drills, got ' .. #drills.all())

local ids = {}
for _, d in ipairs(drills.all()) do
  assert(not ids[d.id], 'duplicate drill id: ' .. tostring(d.id))
  ids[d.id] = true
  assert(type(d.before) == 'table' and #d.before > 0, d.id .. ': before must be lines')
  assert(type(d.after) == 'table' and #d.after > 0, d.id .. ': after must be lines')
  assert(not vim.deep_equal(d.before, d.after), d.id .. ': before == after')
  assert(type(d.optimal) == 'number' and d.optimal > 0, d.id .. ': optimal must be > 0')
  assert(d.solution and d.solution ~= '', d.id .. ': solution must be documented')
  assert(not d.solution:find(' '), d.id .. ': solution must be space-free -- a '
    .. 'literal space is itself a keystroke')
  assert(d.group and d.group ~= '', d.id .. ': group required')
end

-- PIN INTEGRITY. This is the drift detector: a renamed or deleted map fails the
-- build instead of leaving a drill that trains a dead key.
-- maparg needs different spellings for different keys -- it does not expand
-- <leader>, but it also will not match pre-translated <A-j> bytes -- so try
-- the raw notation and the keycoded form.
local function resolves(lhs, mode)
  for _, k in ipairs({ lhs, vim.keycode(lhs) }) do
    local m = vim.fn.maparg(k, mode, false, true)
    if type(m) == 'table' and not vim.tbl_isempty(m) then return true end
  end
  return false
end

local pinned = 0
for _, d in ipairs(drills.all()) do
  if d.lhs then
    pinned = pinned + 1
    assert(resolves(d.lhs, d.mode or 'n'),
      ('drill %q pins %q (mode %s), which resolves to no mapping')
        :format(d.id, d.lhs, d.mode or 'n'))
  end
end
-- Guard against the detector going vacuous if pins were quietly dropped.
assert(pinned >= 14, 'expected >=14 pinned drills, got ' .. pinned)

print(('tutor.drills: ok (%d exercises, %d pins all resolve)'):format(#drills.all(), pinned))

-- SOLVABILITY. The `after` state and `optimal` count are the whole product: if
-- a drill cannot be reached by its own documented solution, the user is scored
-- against a target that does not exist. Replay each solution and require the
-- target state. This is what catches an upstream mini.nvim change to splitjoin
-- padding or surround behaviour, which no amount of static review would.
local function replay(d)
  local b = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(b)
  vim.bo[b].filetype = d.filetype or 'lua'
  vim.api.nvim_buf_set_lines(b, 0, -1, false, d.before)
  pcall(vim.api.nvim_win_set_cursor, 0, d.cursor or { 1, 0 })
  pcall(function() vim.api.nvim_feedkeys(vim.keycode(d.solution), 'xt', false) end)
  -- clear any pending operator or visual state before the next case
  pcall(function() vim.api.nvim_feedkeys(vim.keycode('<Esc><Esc>'), 'xt', false) end)
  return vim.api.nvim_buf_get_lines(b, 0, -1, false)
end

-- replay() makes its scratch buffer current, which would strip the
-- buffer-local LSP maps out of `inventory` for every later assertion. Restore
-- the LspAttach'd buffer afterwards.
local lsp_buf = vim.api.nvim_get_current_buf()
for _, d in ipairs(drills.all()) do
  local got = replay(d)
  assert(vim.deep_equal(got, d.after), ('drill %q is not solvable by its own '
    .. 'solution %q\n  expected: %s\n  got:      %s')
    :format(d.id, d.solution, vim.inspect(d.after), vim.inspect(got)))
end
if vim.api.nvim_buf_is_valid(lsp_buf) then
  vim.api.nvim_set_current_buf(lsp_buf)
end

print(('tutor.drills solvability: ok (all %d solutions reach their target)')
  :format(#drills.all()))

local lessons = require('tutor.lessons')

local chapters = lessons.chapters()
assert(#chapters > 0, 'expected chapters')

local by_key = {}
for _, c in ipairs(chapters) do
  by_key[c.key] = c
  assert(c.title and c.title ~= '', c.key .. ': title required')
  assert(c.blurb and c.blurb ~= '', c.key .. ': blurb required')
end

-- Every non-empty inventory group MUST have a chapter, or maps in a newly
-- introduced group would silently never be taught.
local inv_groups = require('tutor.inventory').groups()
for group, entries in pairs(inv_groups) do
  assert(by_key[group],
    ('inventory group %q (%d maps) has no lesson chapter'):format(group, #entries))
end

-- LspAttach fired earlier in this file, so the lsp chapter must be populated.
assert(by_key.lsp and by_key.lsp.available, 'lsp chapter must be available after LspAttach')
assert(#by_key.lsp.entries > 10, 'lsp chapter should carry the ~21 buffer-local maps')

-- Pickers must be taught by lessons even though they are undrillable.
assert(by_key.pick and #by_key.pick.entries > 5, 'pick chapter must list the finders')

print(('tutor.lessons: ok (%d chapters)'):format(#chapters))

local ui = require('tutor.ui')

-- float() must produce a closable read-only scratch buffer.
local fbuf, fwin = ui.float({ 'line one', 'line two' }, { title = 'test' })
assert(vim.api.nvim_buf_is_valid(fbuf), 'float buffer must be valid')
assert(vim.api.nvim_win_is_valid(fwin), 'float window must be valid')
assert(vim.bo[fbuf].modifiable == false, 'float must be read-only')
assert(vim.api.nvim_buf_get_lines(fbuf, 0, -1, false)[1] == 'line one')
vim.api.nvim_win_close(fwin, true)

-- Lesson index must mention a chapter title and a normalised keymap.
local blob = table.concat(ui.lesson_lines(), '\n')
assert(blob:find('Fuzzy finding', 1, true), 'lesson index must list chapter titles')
assert(blob:find('<leader>ff', 1, true), 'lesson index must show normalised lhs')
assert(blob:find('LSP navigation', 1, true), 'lesson index must include the lsp chapter')

-- Result panel must report keystrokes, time and the optimal solution.
local rl = table.concat(ui.result_lines(
  { id = 'x', solution = 'saiw"', optimal = 5 },
  { keys = 7, optimal = 5, ratio = 1.4, ms = 2100 }), '\n')
assert(rl:find('7', 1, true) and rl:find('5', 1, true), 'must show keys vs optimal')
assert(rl:find('2.1', 1, true), 'must show elapsed seconds')
assert(rl:find('saiw"', 1, true), 'must show the optimal solution')

-- Drill panel must show the target lines and the optimal count.
local dl = table.concat(ui.drill_lines(drills.all()[1], 1, 18), '\n')
assert(dl:find('Target:', 1, true), 'drill panel must show a target')
assert(dl:find(drills.all()[1].after[1], 1, true), 'drill panel must show target text')

-- Stats renders with an empty progress file.
require('tutor.progress').reset()
assert(table.concat(ui.stats_lines(), '\n'):find('No drills attempted', 1, true),
  'stats must handle empty progress')

print('tutor.ui: ok')

-- attach_briefing must not alter buffer content -- the completion predicate
-- compares buffer lines to the target, so briefing text in the buffer would
-- make every drill unsolvable.
local bbuf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(bbuf, 0, -1, false, { 'hello' })
ui.attach_briefing(bbuf, { 'Target:', '  "hello"' })
assert(vim.deep_equal(vim.api.nvim_buf_get_lines(bbuf, 0, -1, false), { 'hello' }),
  'attach_briefing must not modify buffer lines')
local marks = vim.api.nvim_buf_get_extmarks(bbuf,
  vim.api.nvim_create_namespace('tutor_briefing'), 0, -1, {})
assert(#marks == 1, 'attach_briefing must set exactly one extmark, got ' .. #marks)
ui.attach_briefing(bbuf, { 'again' })
marks = vim.api.nvim_buf_get_extmarks(bbuf,
  vim.api.nvim_create_namespace('tutor_briefing'), 0, -1, {})
assert(#marks == 1, 'attach_briefing must replace, not stack, extmarks')
print('tutor.ui briefing: ok')

local tutor = require('tutor')

for _, fn in ipairs({ 'open', 'drill', 'stats', 'reset', 'skip', 'command', 'complete' }) do
  assert(type(tutor[fn]) == 'function', 'tutor.' .. fn .. ' must exist')
end

-- Completion offers the subcommands plus the drill groups.
local comp = tutor.complete('')
local cset = {}
for _, c in ipairs(comp) do cset[c] = true end
assert(cset.drill and cset.stats and cset.reset and cset.skip,
  'subcommands must complete: ' .. vim.inspect(comp))
assert(cset.surround, 'drill groups must complete: ' .. vim.inspect(comp))
assert(#tutor.complete('dr') == 1 and tutor.complete('dr')[1] == 'drill',
  'prefix filtering must work')

-- :Dojo must exist and <leader>l must remain unmapped (flake.nix asserts it).
assert(vim.fn.exists(':Dojo') == 2, ':Dojo command must be registered')
assert(vim.fn.exists(':Tutor') == 2, ':Tutor built-in must remain untouched')
assert(vim.fn.maparg('<leader>l', 'n') == '', '<leader>l must stay unmapped')

-- Tutor keymaps are registered and describe themselves.
for _, lhs in ipairs({ '<leader>tt', '<leader>td', '<leader>ts' }) do
  local m = vim.fn.maparg(vim.keycode(lhs), 'n', false, true)
  assert(type(m) == 'table' and not vim.tbl_isempty(m), lhs .. ' must be mapped')
  assert((m.desc or ''):match('^Tutor'),
    lhs .. ' desc should start with "Tutor": ' .. vim.inspect(m.desc))
end

-- An unknown group must warn, not error, and must not start a session.
tutor.drill('no-such-group')
assert(require('tutor.session').active() == nil,
  'unknown group must not start a session')

require('tutor.progress').reset()
print('tutor.init: ok')

-- BRIEFING PLACEMENT. The older assertion above only checks that an extmark
-- EXISTS, which is exactly why a briefing that never drew a pixel shipped
-- green. Virtual lines anchored ABOVE line 1 reserve no space -- no window can
-- scroll higher than the first line -- so what has to be asserted is where the
-- briefing anchors and which side of the anchor it renders on.
local briefing_ns = vim.api.nvim_create_namespace('tutor_briefing')

local function briefing_mark(b)
  local marks = vim.api.nvim_buf_get_extmarks(b, briefing_ns, 0, -1, { details = true })
  assert(#marks == 1, 'expected exactly one briefing extmark, got ' .. #marks)
  return marks[1][2], marks[1][4]
end

local function briefing_text(details)
  local out = {}
  for _, vline in ipairs(details.virt_lines or {}) do
    local chunks = {}
    for _, chunk in ipairs(vline) do chunks[#chunks + 1] = chunk[1] end
    out[#out + 1] = table.concat(chunks)
  end
  return table.concat(out, '\n')
end

local pbuf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(pbuf, 0, -1, false, { 'local t = {', '  a = 1,', '}' })
ui.attach_briefing(pbuf, { 'Target:', '    x = 1' })

local prow, pdet = briefing_mark(pbuf)
assert(pdet.virt_lines_above == false,
  'briefing must render BELOW its anchor: virt_lines above line 1 are never drawn')
assert(prow == 2,
  'briefing must anchor on the last line of the exercise (row 2), got row ' .. prow)
assert(briefing_text(pdet):find('Target:', 1, true),
  'briefing extmark must carry the target text, got: ' .. briefing_text(pdet))

-- Drift: splitjoin drills change the line count mid-drill, so the anchor has to
-- follow the buffer. Re-anchoring reuses the same extmark id, so it moves the
-- briefing rather than stacking a second one.
vim.api.nvim_buf_set_lines(pbuf, 0, -1, false,
  { 'local t = {', '  a = 1,', '  b = 2', '}' })
ui.reanchor_briefing(pbuf)
prow, pdet = briefing_mark(pbuf)
assert(prow == 3, 'briefing must follow the new last line (row 3), got row ' .. prow)
assert(briefing_text(pdet):find('Target:', 1, true),
  're-anchoring must preserve the briefing text')

-- The result panel used to advertise <leader>td, which rebuilds a fresh
-- weakest-first queue and silently ejects the user from a group run.
local nextline = table.concat(ui.result_lines(
  { id = 'x', solution = 'saiw"', optimal = 5 },
  { keys = 7, optimal = 5, ratio = 1.4, ms = 2100 }), '\n')
assert(nextline:find(':Dojo skip', 1, true),
  'result panel must advertise the command that actually advances the queue')
assert(not nextline:find('<leader>td', 1, true),
  '<leader>td rebuilds the queue; it must not be offered as "next"')

-- The briefing sits below the exercise now, so the footer must point up at it.
assert(table.concat(ui.drill_lines(drills.all()[1], 1, 18), '\n'):find('above', 1, true),
  'drill footer must say the buffer to edit is above the briefing')

print('tutor.ui briefing placement: ok')

-- DRILL WINDOW. A drill gets its own tab, and the tab is REUSED across the
-- queue: the old `botright split` stacked a fresh window on every skip and
-- never closed the previous one.
local base_tabs = #vim.api.nvim_list_tabpages()
local surround_set = drills.by_group('surround')
tutor.drill('surround')

assert(#vim.api.nvim_list_tabpages() == base_tabs + 1,
  'drill must open exactly one new tab, got ' .. #vim.api.nvim_list_tabpages())

local dhandle = require('tutor.session').active()
assert(dhandle, 'drill must start a session')
local dwin = vim.api.nvim_get_current_win()
assert(vim.api.nvim_win_get_buf(dwin) == dhandle.buf,
  'the drill window must display the drill buffer')

local drow, ddet = briefing_mark(dhandle.buf)
assert(ddet.virt_lines_above == false, 'drill briefing must render below the exercise')
assert(drow == #surround_set[1].before - 1,
  ('drill briefing must anchor on row %d, got %d')
    :format(#surround_set[1].before - 1, drow))
assert(briefing_text(ddet):find(surround_set[1].after[1], 1, true),
  'the drill briefing must show the target text the user has to reach')

-- Skipping reuses the tab AND the window inside it.
local tab_wins = #vim.api.nvim_tabpage_list_wins(vim.api.nvim_win_get_tabpage(dwin))
tutor.skip()
assert(#vim.api.nvim_list_tabpages() == base_tabs + 1,
  'skip must not open a second tab, got ' .. #vim.api.nvim_list_tabpages())
assert(#vim.api.nvim_tabpage_list_wins(vim.api.nvim_get_current_tabpage()) == tab_wins,
  'skip must reuse the drill window instead of splitting another one')

-- Draining the queue returns the user to the layout they started from.
for _ = 1, #surround_set - 1 do tutor.skip() end
assert(#vim.api.nvim_list_tabpages() == base_tabs,
  'the drill tab must close when the set completes, got '
    .. #vim.api.nvim_list_tabpages())
assert(require('tutor.session').active() == nil,
  'no session may survive queue exhaustion')

-- Line-count drift through the real session, which is where it actually bites.
local sj_set = drills.by_group('splitjoin')
tutor.drill('splitjoin')
local sjh = require('tutor.session').active()
assert(sjh, 'splitjoin drill must start a session')
assert(briefing_mark(sjh.buf) == #sj_set[1].before - 1,
  'splitjoin briefing must start on the last line of the exercise')

-- A partial edit: more lines than `before`, but not the target, so the
-- completion predicate does not fire and the drill stays open.
local partial = { 'local t = {', '  a = 1,', '  b = 2 }' }
assert(not vim.deep_equal(partial, sj_set[1].after),
  'the partial edit must not match the target, or this asserts nothing')
vim.api.nvim_buf_set_lines(sjh.buf, 0, -1, false, partial)
vim.api.nvim_exec_autocmds('TextChanged', { buffer = sjh.buf })
assert(briefing_mark(sjh.buf) == #partial - 1,
  ('briefing must re-anchor to the new last line (%d), got %d')
    :format(#partial - 1, briefing_mark(sjh.buf)))

for _ = 1, #sj_set do tutor.skip() end
assert(#vim.api.nvim_list_tabpages() == base_tabs,
  'the splitjoin drill tab must close on exhaustion too')

require('tutor.progress').reset()
print('tutor.init drill window: ok')

-- tutor.hunts corpus integrity
do
  local hunts = require('tutor.hunts')
  local all = hunts.all()
  assert(#all >= 4, 'expected at least 4 hunts, got ' .. #all)

  local seen = {}
  local drill_ids = {}
  for _, d in ipairs(require('tutor.drills').all()) do
    drill_ids[d.id] = true
  end

  for _, h in ipairs(all) do
    assert(type(h.id) == 'string' and h.id ~= '', 'hunt missing id')
    assert(not seen[h.id], 'duplicate hunt id: ' .. h.id)
    assert(not drill_ids[h.id], 'hunt id collides with drill id: ' .. h.id)
    seen[h.id] = true
    assert(type(h.group) == 'string' and h.group ~= '', h.id .. ': missing group')
    assert(type(h.goal) == 'string' and h.goal ~= '', h.id .. ': missing goal')
    assert(type(h.optimal) == 'number' and h.optimal > 0, h.id .. ': optimal must be > 0')
    assert(type(h.solution) == 'string' and h.solution ~= '', h.id .. ': missing solution')

    -- Anti-rot: each location must resolve to exactly one line.
    local spath, sline, scol = hunts.resolve(h.start)
    assert(vim.fn.filereadable(spath) == 1, h.id .. ': start file unreadable: ' .. spath)
    assert(sline > 0, h.id .. ': start pattern did not resolve')
    local tpath, tline = hunts.resolve(h.target)
    assert(vim.fn.filereadable(tpath) == 1, h.id .. ': target file unreadable: ' .. tpath)
    assert(tline > 0, h.id .. ': target pattern did not resolve')
    assert(not (spath == tpath and sline == tline), h.id .. ': start and target are the same location')

    -- The start cursor must land ON the symbol. `optimal` assumes it (gd from
    -- column 0 of an indented line is not 2 keystrokes), and so does the
    -- readiness probe, which asks for a definition at exactly this position.
    assert(type(h.start.word) == 'string' and h.start.word ~= '',
      h.id .. ': start must name the word the cursor lands on')
    local sline_text = vim.fn.readfile(spath)[sline]
    assert(sline_text:sub(scol + 1, scol + #h.start.word) == h.start.word,
      ('%s: start col %d does not sit on %q in %q')
        :format(h.id, scol, h.start.word, sline_text))

    -- The readiness probe is the request the solution actually makes. Without
    -- it the clock can start on an answer that does not reach the target: a
    -- definition at a declaration answers with itself, and a cross-file
    -- definition answers with the local import for several seconds first.
    assert(type(h.probe) == 'table' and type(h.probe.method) == 'string',
      h.id .. ': needs a probe method')
    if h.probe.method == 'workspace/symbol' then
      assert(type(h.probe.query) == 'string' and h.probe.query ~= '',
        h.id .. ': a workspace/symbol probe needs a query')
    end
  end
  print('tutor.hunts: ok (' .. #all .. ' hunts)')
end

-- tutor.hunts.resolve rejects ambiguity
do
  local hunts = require('tutor.hunts')
  local ok = pcall(hunts.resolve, { file = 'auth/session.ts', pattern = 'token' })
  assert(not ok, 'resolve must error when a pattern matches multiple lines')
  local ok2 = pcall(hunts.resolve, { file = 'auth/session.ts', pattern = 'zzz_no_such_text' })
  assert(not ok2, 'resolve must error when a pattern matches nothing')
  local ok3 = pcall(hunts.resolve,
    { file = 'auth/session.ts', pattern = '^export function refresh%(', word = 'zzz' })
  assert(not ok3, 'resolve must error when the word is absent from the resolved line')
  print('tutor.hunts.resolve: ok (rejects 0 and >1 matches)')
end

-- tutor.hunt lifecycle
--
-- The readiness gate is stubbed throughout. A live tsserver would turn these
-- into timing tests of vtsls -- ~8s of indexing per hunt, measured -- and the
-- lifecycle being pinned here (start location, path-aware predicate, teardown)
-- needs no server at all. The stub still proves the one thing the gate exists
-- for: that the keystroke clock has not started while readiness is undecided.
do
  local hunt = require('tutor.hunt')
  local hunts = require('tutor.hunts')
  local h = hunts.by_id('symbol-decoy-definition')

  -- The four LSP result shapes the servers in this config actually send. This
  -- is the part that rots, and it is pure, so it is pinned without a server.
  local tgt = '/tmp/x/auth/session.ts'
  local uri = vim.uri_from_fname(tgt)
  assert(hunt.answer_reaches({ { result = { { uri = uri } } } }, tgt), 'Location{uri}')
  assert(hunt.answer_reaches({ { result = { { targetUri = uri } } } }, tgt), 'LocationLink{targetUri}')
  assert(hunt.answer_reaches({ { result = { { location = { uri = uri } } } } }, tgt),
    'SymbolInformation{location={uri}}')
  assert(hunt.answer_reaches({ { result = { { uri = 'file:///nope.ts' }, { targetUri = uri } } } }, tgt),
    'must scan past a non-matching result')
  assert(not hunt.answer_reaches({ { result = {} } }, tgt), 'an empty result reaches nothing')
  assert(not hunt.answer_reaches(nil, tgt), 'a nil response reaches nothing')
  assert(not hunt.answer_reaches({ { result = { { uri = vim.uri_from_fname('/tmp/x/util/validate.ts') } } } }, tgt),
    'the decoy must not count as reaching the target')

  local real_await = hunt.await_lsp
  local saw = {}
  hunt.await_lsp = function(buf, _, o)
    local pending = hunt.active()
    saw.active = pending ~= nil
    saw.started_at = pending and pending.started_at
    saw.buf = buf
    saw.opts = o
    return true
  end

  local completed = nil
  local handle = hunt.start(h, { on_complete = function(score) completed = score end })
  assert(handle, 'hunt.start must return a handle when the server is ready')

  -- 1. lands on the start location, cursor ON the symbol
  local spath, sline, scol = hunts.resolve(h.start)
  assert(vim.fs.normalize(vim.api.nvim_buf_get_name(0)) == spath,
    'expected to start in ' .. spath .. ', got ' .. vim.api.nvim_buf_get_name(0))
  assert(vim.api.nvim_win_get_cursor(0)[1] == sline, 'cursor not on start line')
  assert(vim.api.nvim_win_get_cursor(0)[2] == scol,
    ('cursor not on the start word: col %d, want %d')
      :format(vim.api.nvim_win_get_cursor(0)[2], scol))

  -- 2. the clock starts only after readiness
  assert(saw.active, 'the handle must exist while await_lsp runs')
  assert(saw.started_at == nil, 'started_at was set BEFORE await_lsp returned')
  assert(saw.buf == handle.buf, 'await_lsp must probe the hunt buffer')
  -- Readiness is "the server can answer THIS hunt's question with THIS hunt's
  -- target", not "the server replied".
  assert(saw.opts and saw.opts.probe == h.probe, 'await_lsp must be given the hunt probe')
  assert(saw.opts.target == select(1, hunts.resolve(h.target)),
    'await_lsp must be given the resolved target path')
  assert(handle.keys == 0, 'keystroke counter must start at zero')
  assert(type(handle.started_at) == 'number', 'started_at must be set after readiness')

  -- 3. fixture buffers are read-only
  assert(vim.bo[handle.buf].modifiable == false, 'fixture buffer must not be modifiable')

  -- 4. The autocmds must be GLOBAL. session.lua scopes its trigger to the one
  -- drill buffer; a hunt succeeds by LEAVING its start buffer, so a
  -- buffer-scoped autocmd would never fire at the target and no hunt could
  -- ever complete. Also pin the trigger set: TextChanged is the drill's
  -- trigger and is useless here.
  local aus = vim.api.nvim_get_autocmds({ group = handle.augroup })
  assert(#aus > 0, 'hunt must register autocmds')
  local events = {}
  for _, au in ipairs(aus) do
    events[au.event] = true
    assert(au.buffer == nil,
      'hunt autocmds must be global, but one is scoped to buffer ' .. tostring(au.buffer))
  end
  for _, want in ipairs({ 'CursorMoved', 'CursorMovedI', 'BufEnter', 'WinEnter' }) do
    assert(events[want], 'hunt must listen for ' .. want)
  end
  assert(not events.TextChanged, 'hunt must not use the drill trigger')

  -- 5. The TARGET LINE NUMBER in the WRONG FILE must not complete the hunt.
  -- Deliberately not a trivial "move somewhere else" check: that would pass
  -- vacuously if no predicate ran at all. This proves the predicate compares
  -- the PATH, not just the line number.
  local tpath, tline = hunts.resolve(h.target)
  assert(vim.fn.line('$') >= tline, 'start file too short for this probe to mean anything')
  vim.api.nvim_win_set_cursor(0, { tline, 0 })
  assert(vim.api.nvim_win_get_cursor(0)[1] == tline, 'cursor did not move -- test would be vacuous')
  -- CursorMoved is raised from nvim's main loop, which a headless -c script
  -- never reaches; the existing drill tests fire TextChanged by hand for the
  -- same reason (see the splitjoin block above).
  vim.api.nvim_exec_autocmds('CursorMoved', {})
  assert(completed == nil, 'hunt completed on the right line of the WRONG file')

  -- 6. reaching the target location DOES complete it
  vim.cmd('edit ' .. vim.fn.fnameescape(tpath))
  vim.api.nvim_win_set_cursor(0, { tline, 0 })
  vim.api.nvim_exec_autocmds('CursorMoved', {})
  assert(completed ~= nil, 'hunt did not complete at the target location')
  assert(type(completed.ratio) == 'number', 'score must carry a ratio')
  assert(completed.optimal == h.optimal, 'score must carry the hunt optimal')

  hunt.stop(handle)
  assert(hunt.active() == nil, 'stop must clear the active handle')
  hunt.stop(handle)

  hunt.await_lsp = real_await
  print('tutor.hunt: ok (starts on the symbol, rejects wrong file, completes at target)')
end

-- A hunt whose server never becomes ready must not be presented as scoreable.
do
  local hunt = require('tutor.hunt')
  local hunts = require('tutor.hunts')
  local real_await = hunt.await_lsp
  hunt.await_lsp = function() return false end

  local fired = false
  local handle = hunt.start(hunts.by_id('symbol-decoy-definition'),
    { on_complete = function() fired = true end })
  assert(handle == nil, 'start must return nil when the language server never answers')
  assert(hunt.active() == nil, 'a hunt that cannot be completed must not stay active')
  assert(not fired, 'on_complete must not fire for an ungated hunt')

  hunt.await_lsp = real_await
  print('tutor.hunt readiness: ok (no session without a ready server)')
end

-- tutor.init hunt teardown leaves the editor as it found it
do
  local hunt = require('tutor.hunt')
  local real_await = hunt.await_lsp
  hunt.await_lsp = function() return true end

  for _, fn in ipairs({ 'hunt', 'hunt_skip' }) do
    assert(type(tutor[fn]) == 'function', 'tutor.' .. fn .. ' must exist')
  end

  -- Hunt groups belong AFTER the subcommand. Drill groups are offered at the
  -- top level, which is a pre-existing wart -- `:Dojo sur<Tab>` completes to an
  -- invalid `:Dojo surround` -- and not one worth spreading to hunts.
  local top = {}
  for _, c in ipairs(tutor.complete('')) do top[c] = true end
  assert(top.hunt and top['hunt-skip'], 'hunt subcommands must complete')
  assert(not top.symbol, 'hunt groups must not leak into the top-level completion')
  local after = {}
  for _, c in ipairs(tutor.complete('', 'Dojo hunt ')) do after[c] = true end
  assert(after.symbol, ':Dojo hunt <Tab> must offer hunt groups')

  -- <leader>th is set by nvim/init.lua, which is only loaded when the config
  -- under test IS this tree: true under nix flake check, which exports
  -- XDG_CONFIG_HOME=$PWD, and false for a bare `set rtp^=` run, which loads the
  -- installed config and can only see keymaps that already shipped. Assert it
  -- where it is observable instead of failing where it cannot be.
  if vim.fs.normalize(vim.fn.stdpath('config'))
    == vim.fs.normalize(vim.fn.getcwd() .. '/nvim') then
    local thmap = vim.fn.maparg(vim.keycode('<leader>th'), 'n', false, true)
    assert(type(thmap) == 'table' and not vim.tbl_isempty(thmap), '<leader>th must be mapped')
    assert((thmap.desc or ''):match('^Tutor'),
      '<leader>th desc should start with "Tutor": ' .. vim.inspect(thmap.desc))
  end

  local tabs_before = #vim.api.nvim_list_tabpages()
  local bufs_before = #vim.api.nvim_list_bufs()

  tutor.hunt('symbol')
  assert(#vim.api.nvim_list_tabpages() == tabs_before + 1, 'hunt must open exactly one tab')
  assert(hunt.active(), 'hunt must start a session')

  -- More skips than hunts: draining the queue must be idempotent, not a crash.
  for _ = 1, 10 do
    tutor.hunt_skip()
  end

  assert(#vim.api.nvim_list_tabpages() == tabs_before,
    'hunt tab leaked: ' .. #vim.api.nvim_list_tabpages() .. ' vs ' .. tabs_before)
  assert(#vim.api.nvim_list_bufs() == bufs_before,
    'fixture buffers leaked: ' .. #vim.api.nvim_list_bufs() .. ' vs ' .. bufs_before)
  assert(hunt.active() == nil, 'no hunt may survive queue exhaustion')

  -- An unknown group must warn, not error, and must not open a tab.
  tutor.hunt('no-such-group')
  assert(hunt.active() == nil, 'unknown hunt group must not start a session')
  assert(#vim.api.nvim_list_tabpages() == tabs_before,
    'unknown hunt group must not open a tab')

  hunt.await_lsp = real_await
  print('tutor.init hunt: ok (one tab, clean teardown, no buffer leak)')
end

require('tutor.progress').reset()
print('ALL TUTOR TESTS PASSED')
