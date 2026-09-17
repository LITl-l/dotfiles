-- Navigation hunts: cross-file drills over the committed TypeScript fixture.
--
-- Unlike drills.lua, a hunt has no target buffer text. It completes when the
-- cursor reaches a resolved location in a real file. Locations are PATTERNS,
-- not line numbers, so editing the fixture moves the hunts with it; a pattern
-- matching zero or several lines is a test failure, not a silent drift.
--
-- A `start` also names the `word` the cursor lands on. `optimal` assumes it --
-- `gd` is two keystrokes only when the cursor is already on the symbol, not at
-- column 0 of an indented line -- and so do the three positional readiness
-- probes below, which ask the server a question at exactly that position and
-- would otherwise wait out their timeout on whitespace.
--
-- `probe` is the request the solution actually makes. hunt.lua starts the
-- keystroke clock only once that request comes back pointing at this hunt's
-- own target, which doubles as the solvability check drills get from replaying
-- their solution and hunts otherwise have no equivalent of. Two measurements
-- forced this: a definition request at a DECLARATION (store/iface.ts) answers
-- instantly with itself while the implementation index is still cold, and a
-- definition request at api/handler.ts answers with the local import specifier
-- for the first several seconds before it resolves across the file boundary.
-- Either one satisfies "the server responded" while the hunt is still
-- unwinnable.

local M = {}

local function source_dir()
  local src = debug.getinfo(1, 'S').source:sub(2)
  return vim.fn.fnamemodify(src, ':h')
end

function M.root()
  -- .../nvim/lua/tutor/hunts.lua -> .../nvim/tutor-fixture
  return vim.fs.normalize(source_dir() .. '/../../tutor-fixture')
end

-- Returns absolute path, 1-based line, and 0-based column. The column is the
-- byte offset of `loc.word` on the resolved line, or 0 when the location does
-- not name one (targets do not: the predicate compares the line, and the route
-- to it is deliberately free).
function M.resolve(loc)
  local path = vim.fs.normalize(M.root() .. '/' .. loc.file)
  local lines = vim.fn.readfile(path)
  if type(lines) ~= 'table' then
    error('hunts.resolve: unreadable file: ' .. path)
  end
  local found
  for i, line in ipairs(lines) do
    if line:match(loc.pattern) then
      if found then
        error(('hunts.resolve: pattern %q matches lines %d and %d in %s')
          :format(loc.pattern, found, i, loc.file))
      end
      found = i
    end
  end
  if not found then
    error(('hunts.resolve: pattern %q matched nothing in %s'):format(loc.pattern, loc.file))
  end

  local col = 0
  if loc.word then
    local at = lines[found]:find(loc.word, 1, true)
    if not at then
      error(('hunts.resolve: word %q is absent from %s:%d (%q)')
        :format(loc.word, loc.file, found, lines[found]))
    end
    col = at - 1
  end
  return path, found, col
end

local hunts = {
  {
    id = 'symbol-decoy-definition',
    group = 'symbol',
    start = { file = 'api/handler.ts', pattern = 'if %(!validate%(token%)%)', word = 'validate' },
    goal = 'Reach the validate that actually runs -- not util/validate.ts.',
    target = { file = 'auth/session.ts', pattern = '^export function validate%(' },
    optimal = 2,
    solution = 'gd',
    needs_lsp = true,
    probe = { method = 'textDocument/definition' },
  },
  {
    id = 'symbol-callers',
    group = 'symbol',
    start = { file = 'auth/session.ts', pattern = '^export function validate%(', word = 'validate' },
    goal = 'From the definition, reach the HTTP handler that calls it.',
    target = { file = 'api/handler.ts', pattern = 'if %(!validate%(token%)%)' },
    optimal = 4,
    solution = 'gr',
    needs_lsp = true,
    probe = {
      method = 'textDocument/references',
      context = { includeDeclaration = false },
    },
  },
  {
    id = 'symbol-implementation',
    group = 'symbol',
    start = { file = 'store/iface.ts', pattern = '  get%(key: string%)', word = 'get' },
    goal = 'From the Store interface, reach the concrete get implementation.',
    target = { file = 'store/memory.ts', pattern = '  get%(key: string%)' },
    optimal = 4,
    solution = 'gI',
    needs_lsp = true,
    probe = { method = 'textDocument/implementation' },
  },
  {
    id = 'symbol-workspace-refresh',
    group = 'symbol',
    start = { file = 'api/handler.ts', pattern = '^export function handle%(', word = 'handle' },
    goal = 'Reach refresh by workspace symbol search, without opening the file by name.',
    target = { file = 'auth/session.ts', pattern = '^export function refresh%(' },
    optimal = 10,
    solution = '<leader>ws',
    needs_lsp = true,
    -- Not positional: the workspace symbol picker is driven by a query, so the
    -- start cursor is irrelevant to whether the server can answer this one.
    probe = { method = 'workspace/symbol', query = 'refresh' },
  },
}

function M.all()
  return hunts
end

function M.groups()
  local set, out = {}, {}
  for _, h in ipairs(hunts) do
    if not set[h.group] then
      set[h.group] = true
      out[#out + 1] = h.group
    end
  end
  table.sort(out)
  return out
end

function M.by_group(group)
  local out = {}
  for _, h in ipairs(hunts) do
    if h.group == group then
      out[#out + 1] = h
    end
  end
  return out
end

function M.by_id(id)
  for _, h in ipairs(hunts) do
    if h.id == id then
      return h
    end
  end
  return nil
end

-- Weakest-first, sharing progress.lua with drills. Ids are namespaced 'hunt:'
-- so the two corpora cannot collide in one stats file.
function M.weakest(n)
  local progress = require('tutor.progress')
  local ids = {}
  for _, h in ipairs(hunts) do
    ids[#ids + 1] = 'hunt:' .. h.id
  end
  local ranked = progress.rank(ids, os.time())
  local out = {}
  for _, id in ipairs(ranked) do
    local h = M.by_id((id:gsub('^hunt:', '')))
    if h then
      out[#out + 1] = h
    end
    if #out >= (n or #hunts) then
      break
    end
  end
  return out
end

return M
