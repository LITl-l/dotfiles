-- Layer 1 of the tutor's content model: the keymap inventory, derived from live
-- keymaps so it cannot drift from the config.
--
-- Two non-obvious facts drive this module:
--  1. nvim_get_keymap() returns only GLOBAL maps. The ~21 LSP maps in
--     config/autocmds.lua are buffer-local (set with { buffer = event.buf }),
--     so nvim_buf_get_keymap() must be merged in or the LSP group is empty.
--  2. lhs comes back with the leader already expanded to its literal key
--     (" ff", not "<leader>ff"), so it must be normalised before matching.

local M = {}

M.GROUP_ORDER = {
  'core', 'files', 'pick', 'windows', 'tabs',
  'surround', 'goto', 'code', 'lsp', 'git', 'toggles', 'debug', 'tutor', 'other',
}

-- Checked in order, so longer prefixes must come first.
local LHS_GROUPS = {
  { '<leader><Tab>', 'tabs' },
  { '<leader>f',     'pick' },
  { '<leader>u',     'toggles' },
  { '<leader>d',     'debug' },
  { '<leader>g',     'git' },
  { '<leader>c',     'code' },
  { '<leader>r',     'code' },
  { '<leader>s',     'code' },
  { '<leader>t',     'tutor' },
  { '<leader>w',     'windows' },
  { '<leader>-',     'windows' },
  { '<leader>|',     'windows' },
  { '<leader>e',     'files' },
  { '<leader>E',     'files' },
  { '<leader>q',     'files' },
  { '<leader>Q',     'files' },
  { '<leader>b',     'files' },
  { 's',             'surround' },
  { 'g',             'goto' },
}

-- Maps a prefix rule would mis-bucket. '<leader>w' is 'Save file' while
-- '<leader>ww' is a window op; '<leader>fn' is 'New file', not a picker.
local LEAF_OVERRIDES = {
  ['<leader>w'] = 'files',
  ['<leader>W'] = 'files',
  ['<leader>fn'] = 'files',
}

function M.normalise(lhs)
  local leader = vim.g.mapleader
  if type(leader) == 'string' and leader ~= '' and lhs:sub(1, #leader) == leader then
    return '<leader>' .. lhs:sub(#leader + 1)
  end
  return lhs
end

function M.group_of(entry)
  local desc = entry.desc or ''
  -- All 21 buffer-local LSP maps carry this prefix; it outranks any lhs rule,
  -- which is what keeps '<leader>ws' (LSP) out of the 'windows' bucket.
  if desc:match('^LSP: ') then
    return 'lsp'
  end

  local lhs = entry.lhs
  if LEAF_OVERRIDES[lhs] then
    return LEAF_OVERRIDES[lhs]
  end

  for _, rule in ipairs(LHS_GROUPS) do
    local prefix, group = rule[1], rule[2]
    if lhs:sub(1, #prefix) == prefix then
      return group
    end
  end
  return 'core'
end

-- Merge keyed by lhs. vim.list_extend() would append instead of dedupe and
-- yield two contradictory entries for '[d', ']d' and 'gp'.
local function merge(mode, buf)
  local merged = {}
  for _, m in ipairs(vim.api.nvim_get_keymap(mode)) do
    merged[m.lhs] = { lhs = m.lhs, desc = m.desc, buffer_local = false }
  end
  for _, m in ipairs(vim.api.nvim_buf_get_keymap(buf, mode)) do
    merged[m.lhs] = { lhs = m.lhs, desc = m.desc, buffer_local = true }
  end
  return merged
end

function M.entries(opts)
  opts = opts or {}
  local buf = opts.buf or 0
  local mode = opts.mode or 'n'

  local out = {}
  for _, m in pairs(merge(mode, buf)) do
    local desc = m.desc
    if desc and desc ~= '' and not m.lhs:match('^<Plug>') then
      local entry = {
        lhs = M.normalise(m.lhs),
        desc = desc,
        buffer_local = m.buffer_local,
      }
      entry.group = M.group_of(entry)
      out[#out + 1] = entry
    end
  end

  table.sort(out, function(a, b) return a.lhs < b.lhs end)
  return out
end

function M.groups(opts)
  local buckets = {}
  for _, e in ipairs(M.entries(opts)) do
    buckets[e.group] = buckets[e.group] or {}
    table.insert(buckets[e.group], e)
  end
  return buckets
end

-- The LSP group only exists once a client has attached, because its maps are
-- buffer-local. Callers render this as "open a code file" rather than "empty".
function M.lsp_available(opts)
  local buckets = M.groups(opts)
  return buckets.lsp ~= nil and #buckets.lsp > 0
end

return M
