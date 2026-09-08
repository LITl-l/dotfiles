-- Drill progress, persisted as JSON under stdpath('state').
--
-- This must not live under nvim/: that tree is copied into the read-only Nix
-- store by xdg.configFile."nvim", and the flake check redirects XDG_STATE_HOME
-- into $TMPDIR.

local M = {}

local EWMA_ALPHA = 0.4      -- weight of the newest attempt
local RECENCY_CAP_DAYS = 14
local DAY = 86400

function M.path()
  return vim.fs.joinpath(vim.fn.stdpath('state'), 'tutor', 'progress.json')
end

function M.load()
  local path = M.path()
  if vim.fn.filereadable(path) ~= 1 then
    return {}
  end
  local ok, decoded = pcall(function()
    return vim.json.decode(table.concat(vim.fn.readfile(path), '\n'))
  end)
  if not ok or type(decoded) ~= 'table' then
    return {}
  end
  return decoded
end

-- Write to a temp path then rename, so an interrupted write cannot leave a
-- half-serialised file that load() would then silently discard.
function M.save(data)
  local path = M.path()
  vim.fn.mkdir(vim.fs.dirname(path), 'p')
  local tmp = path .. '.tmp'
  vim.fn.writefile(vim.split(vim.json.encode(data), '\n'), tmp)
  local ok = (vim.uv or vim.loop).fs_rename(tmp, path)
  if not ok then
    vim.fn.delete(tmp)
  end
end

function M.record(id, score)
  local data = M.load()
  local stat = data[id]
  local ratio = (score.optimal and score.optimal > 0) and (score.keys / score.optimal) or 1

  if stat then
    stat.attempts = stat.attempts + 1
    stat.best_keys = math.min(stat.best_keys, score.keys)
    stat.best_ms = math.min(stat.best_ms, score.ms)
    stat.ewma_ratio = stat.ewma_ratio + EWMA_ALPHA * (ratio - stat.ewma_ratio)
  else
    stat = {
      attempts = 1,
      best_keys = score.keys,
      best_ms = score.ms,
      ewma_ratio = ratio,
    }
  end
  stat.last_seen = os.time()

  data[id] = stat
  M.save(data)
  return stat
end

-- Weakest-first ranking. Never-attempted material always sorts to the top;
-- otherwise a worse keystroke ratio and a longer time since practice both
-- raise the score.
function M.weakness(stat, now)
  if not stat or (stat.attempts or 0) == 0 then
    return math.huge
  end
  now = now or os.time()
  local days = math.max(0, (now - (stat.last_seen or now)) / DAY)
  local recency = 1 + math.min(days, RECENCY_CAP_DAYS)
  return (stat.ewma_ratio or 1) * recency
end

function M.rank(ids, now)
  now = now or os.time()
  local data = M.load()
  local ordered = vim.deepcopy(ids)
  -- Stable: ties fall back to id order so drills do not shuffle between runs.
  local weights = {}
  for i, id in ipairs(ordered) do
    weights[id] = { w = M.weakness(data[id], now), i = i }
  end
  table.sort(ordered, function(a, b)
    if weights[a].w ~= weights[b].w then
      return weights[a].w > weights[b].w
    end
    return weights[a].i < weights[b].i
  end)
  return ordered
end

function M.reset()
  vim.fn.delete(M.path())
end

return M
