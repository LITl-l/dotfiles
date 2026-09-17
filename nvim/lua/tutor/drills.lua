-- Layer 2 of the content model: the authored drill corpus.
--
-- A drill needs what a keymap `desc` cannot supply: a before state, a target
-- state, and an optimal keystroke count. So these are written by hand -- but
-- most pin an `lhs`, and nvim/tests/tutor.lua asserts every pin still resolves.
-- Rename or delete a map and the build fails, rather than the tutor quietly
-- drilling a key that no longer exists.
--
-- Only editing maps appear here. A drill completes when the buffer matches the
-- target text, and '<leader>ff' has no target buffer state -- pickers, toggles
-- and DAP are taught by lessons.lua instead.
--
-- Every `after` and `optimal` below was verified by replaying `solution`
-- through nvim_feedkeys against this config. `optimal` counts KEYSTROKES, not
-- bytes: '<A-k>' is one keystroke. `solution` is space-free because a literal
-- space in the sequence is itself a keystroke.

local progress = require('tutor.progress')

local M = {}

local EXERCISES = {
  -- mini.surround ---------------------------------------------------------
  {
    id = 'surround-add-quotes',
    lhs = 'sa', mode = 'n', group = 'surround',
    before = { 'local greeting = hello' },
    after  = { 'local greeting = "hello"' },
    cursor = { 1, 17 },
    optimal = 5, solution = 'saiw"',
    hint = 'sa = surround add: the key, a motion, then the delimiter to wrap with.',
  },
  {
    id = 'surround-add-parens',
    lhs = 'sa', mode = 'n', group = 'surround',
    before = { 'return value' },
    after  = { 'return (value)' },
    cursor = { 1, 7 },
    optimal = 5, solution = 'saiw)',
    hint = 'Same shape as quoting -- only the final delimiter changes.',
  },
  {
    id = 'surround-delete',
    lhs = 'sd', mode = 'n', group = 'surround',
    before = { 'print("hello")' },
    after  = { 'print(hello)' },
    cursor = { 1, 7 },
    optimal = 3, solution = 'sd"',
    hint = 'sd = surround delete. Name the delimiter to strip.',
  },
  {
    id = 'surround-replace',
    lhs = 'sr', mode = 'n', group = 'surround',
    before = { "local path = 'src'" },
    after  = { 'local path = "src"' },
    cursor = { 1, 14 },
    optimal = 4, solution = "sr'\"",
    hint = 'sr = surround replace: old delimiter, then new.',
  },
  {
    id = 'surround-replace-brackets',
    lhs = 'sr', mode = 'n', group = 'surround',
    before = { 'local t = [1, 2, 3]' },
    after  = { 'local t = {1, 2, 3}' },
    cursor = { 1, 12 },
    optimal = 4, solution = 'sr]}',
    hint = 'Works for any bracket pair, not just quotes.',
  },

  -- mini.comment ----------------------------------------------------------
  {
    id = 'comment-line',
    lhs = 'gcc', mode = 'n', group = 'comment',
    before = { 'local debug = true' },
    after  = { '-- local debug = true' },
    cursor = { 1, 0 },
    optimal = 3, solution = 'gcc',
    hint = 'gcc toggles this line. Treesitter supplies the comment string.',
  },
  {
    id = 'comment-uncomment',
    lhs = 'gcc', mode = 'n', group = 'comment',
    before = { '-- local done = false' },
    after  = { 'local done = false' },
    cursor = { 1, 0 },
    optimal = 3, solution = 'gcc',
    hint = 'It toggles -- the same keystrokes undo it.',
  },
  {
    id = 'comment-motion',
    lhs = 'gc', mode = 'n', group = 'comment',
    before = { 'local a = 1', 'local b = 2' },
    after  = { '-- local a = 1', '-- local b = 2' },
    cursor = { 1, 0 },
    optimal = 3, solution = 'gcj',
    hint = 'gc takes a motion: gcj covers this line and the next.',
  },

  -- mini.splitjoin --------------------------------------------------------
  {
    id = 'splitjoin-split',
    lhs = 'gS', mode = 'n', group = 'splitjoin',
    before = { 'local t = { a = 1, b = 2 }' },
    after  = { 'local t = {', '  a = 1,', '  b = 2', '}' },
    cursor = { 1, 12 },
    optimal = 2, solution = 'gS',
    hint = 'gS splits a one-line collection across lines.',
  },
  {
    id = 'splitjoin-join',
    lhs = 'gS', mode = 'n', group = 'splitjoin',
    before = { 'local t = {', '  a = 1,', '  b = 2', '}' },
    after  = { 'local t = {a = 1, b = 2}' },
    cursor = { 1, 10 },
    optimal = 2, solution = 'gS',
    hint = 'Same key, opposite direction -- it detects which way to go.',
  },

  -- line moves ------------------------------------------------------------
  -- `filetype` pins the drill buffer's language; session.lua defaults it to
  -- 'lua'. Both move-line maps end in '==', so the drill is scored against
  -- whatever the buffer's indent rules do to the moved line. With Lua indent
  -- active, 'second' lands under 'first' as a continuation and is re-indented
  -- to '  second' -- a target the user cannot reach with the documented
  -- solution, because that '==' is part of the mapping's RHS, not of the keys
  -- the user types. Under 'text' the moved line was verified by replay to come
  -- through unchanged, so the drill measures the line move, which is the point.
  {
    id = 'move-line-down',
    lhs = '<A-j>', mode = 'n', group = 'editing',
    filetype = 'text',
    before = { 'second', 'first' },
    after  = { 'first', 'second' },
    cursor = { 1, 0 },
    optimal = 1, solution = '<A-j>',
    hint = 'Alt-j drags this line down and re-indents it.',
  },
  -- No `filetype` here: this one moves a line to the TOP of the buffer, where
  -- every indentexpr agrees on column 0, so '==' cannot perturb the target.
  -- Verified by replay under 'lua', 'text' and no filetype -- all three reach
  -- `after`.
  {
    id = 'move-line-up',
    lhs = '<A-k>', mode = 'n', group = 'editing',
    before = { 'body', 'header' },
    after  = { 'header', 'body' },
    cursor = { 1, 0 },
    optimal = 2, solution = 'j<A-k>',
    hint = 'Alt-k drags upward. Cheaper than delete-and-paste.',
  },

  -- treesitter incremental selection --------------------------------------
  {
    id = 'incremental-select-args',
    lhs = '<C-Space>', mode = 'n', group = 'treesitter',
    before = { 'local sum = add(one, two)' },
    after  = { 'local sum = add(x)' },
    cursor = { 1, 16 },
    optimal = 6, solution = '<C-Space><C-Space>c(x)',
    hint = 'Ctrl-Space grows the selection by syntax node -- no counting motions.',
  },

  -- search and replace ----------------------------------------------------
  {
    id = 'replace-word-under-cursor',
    lhs = '<leader>sr', mode = 'n', group = 'editing',
    before = { 'local tmp = 1', 'return tmp' },
    after  = { 'local total = 1', 'return total' },
    cursor = { 1, 6 },
    optimal = 10, solution = '<leader>sr<C-w>total<CR>',
    hint = 'Prefills a substitute for the word under the cursor. <C-w> clears '
      .. 'the prefilled replacement before you type the new one.',
  },

  -- visual indent ---------------------------------------------------------
  {
    id = 'indent-visual-keep-selection',
    lhs = '>', mode = 'x', group = 'editing',
    before = { 'if x then', 'return 1', 'end' },
    after  = { 'if x then', '  return 1', 'end' },
    cursor = { 1, 0 },
    optimal = 3, solution = 'jV>',
    hint = 'In this config > keeps the visual selection, so you can repeat it.',
  },

  -- core motions worth drilling. No `lhs`: these are built-in Vim, not config
  -- maps, so there is nothing honest to pin them to.
  {
    id = 'change-inner-word',
    mode = 'n', group = 'motions',
    before = { 'local placeholder = 1' },
    after  = { 'local count = 1' },
    cursor = { 1, 0 },
    optimal = 9, solution = 'wciwcount',
    hint = 'ciw replaces a word from anywhere inside it.',
  },
  {
    id = 'delete-to-end',
    mode = 'n', group = 'motions',
    before = { 'local keep = 1 -- drop this' },
    after  = { 'local keep = 1' },
    cursor = { 1, 0 },
    optimal = 4, solution = 'f-hD',
    hint = 'f jumps to a character, h steps back, D deletes to end of line.',
  },
  {
    id = 'join-lines',
    mode = 'n', group = 'motions',
    before = { 'local ok =', '  true' },
    after  = { 'local ok = true' },
    cursor = { 1, 0 },
    optimal = 1, solution = 'J',
    hint = 'J joins the next line up, collapsing the indent to one space.',
  },
}

function M.all()
  return EXERCISES
end

function M.groups()
  local seen, out = {}, {}
  for _, e in ipairs(EXERCISES) do
    if not seen[e.group] then
      seen[e.group] = true
      out[#out + 1] = e.group
    end
  end
  table.sort(out)
  return out
end

function M.by_group(group)
  return vim.tbl_filter(function(e) return e.group == group end, EXERCISES)
end

function M.by_id(id)
  for _, e in ipairs(EXERCISES) do
    if e.id == id then return e end
  end
end

-- Weakest-first, so a drill session spends time where the ratio is worst.
function M.weakest(n)
  local ids = vim.tbl_map(function(e) return e.id end, EXERCISES)
  local out = {}
  for _, id in ipairs(progress.rank(ids)) do
    if #out >= (n or 10) then break end
    out[#out + 1] = M.by_id(id)
  end
  return out
end

return M
