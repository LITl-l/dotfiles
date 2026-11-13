-- Every external tool this config names by string must be runnable by Neovim.
--
-- The class of bug this encodes: conform.nvim names a formatter and nvim-dap
-- names an adapter command, and when the binary is absent NEITHER errors --
-- conform silently skips that formatter, the adapter silently never spawns. The
-- feature simply never happens, so the gap survives until someone notices years
-- later. Four such gaps shipped at once; this test is the invariant they all
-- violated.
--
-- Tool names are read out of the config SOURCE rather than from a loaded
-- conform/dap because `nix flake check` runs with a fresh XDG_DATA_HOME, where
-- the opt plugins home-manager installs under pack/hm/opt do not exist.
-- Availability is then probed with exepath() rather than parsed out of
-- modules/neovim.nix, because the neovim wrapper bakes `extraPackages` into its
-- own PATH: inside the sandbox that wrapper PATH is the only source of tools, so
-- the probe is a stricter test of `extraPackages` there than it can be on a live
-- machine, and it is immune to how the package is spelled in Nix
-- (`gotools` ships `goimports`, `python3.withPackages` ships `python3`).

local script = debug.getinfo(1, 'S').source:gsub('^@', '')
local nvim_dir = vim.fn.fnamemodify(script, ':p:h:h')

local function lines_of(relative)
  local path = nvim_dir .. '/' .. relative
  assert(vim.fn.filereadable(path) == 1, 'cannot read ' .. path)
  return vim.fn.readfile(path)
end

-- conform formatters whose binary is not simply their own name.
local FORMATTER_BINARY = {
  ruff_format = 'ruff',
  ruff_organize_imports = 'ruff',
}

-- conform runs these inside Lua; there is no binary to install.
local NO_BINARY = {
  injected = true,
  squeeze_blanks = true,
  trim_newlines = true,
  trim_whitespace = true,
}

local function formatter_names()
  local names, inside = {}, false
  for _, line in ipairs(lines_of('lua/config/format.lua')) do
    if line:match('formatters_by_ft%s*=%s*{') then
      inside = true
    elseif inside and line:match('^%s*},%s*$') then
      inside = false
    elseif inside then
      local list = line:match('=%s*{(.-)}')
      if list then
        for name in list:gmatch("'([%w_]+)'") do
          names[name] = true
        end
      end
    end
  end
  return names
end

local function dap_adapters()
  local found, current = {}, nil
  for _, line in ipairs(lines_of('lua/config/dap.lua')) do
    local name = line:match('dap%.adapters%.([%w_]+)%s*=')
    if name then
      current = { name = name }
      found[#found + 1] = current
    elseif current then
      current.command = current.command or line:match("command%s*=%s*'([^']+)'")
      if line:match('^%s*}%s*$') then
        current = nil
      end
    end
  end
  return found
end

local formatters = formatter_names()
local adapters = dap_adapters()

-- Vacuity guards. Both extractors read source text, so a reformat of the config
-- could leave them matching nothing and this test green for the wrong reason.
local formatter_count = vim.tbl_count(formatters)
assert(formatter_count >= 10,
  'expected >=10 conform formatters in the config, found ' .. formatter_count
    .. ' -- the extractor has drifted from format.lua')
assert(#adapters >= 1, 'expected >=1 dap adapter in the config, found none')

-- binary -> what names it, for a failure message that points at the cause
local required = {}
local function require_binary(binary, named_by)
  required[binary] = required[binary] or {}
  table.insert(required[binary], named_by)
end

for name in pairs(formatters) do
  if not NO_BINARY[name] then
    require_binary(FORMATTER_BINARY[name] or name, 'conform formatter ' .. name)
  end
end

for _, adapter in ipairs(adapters) do
  assert(adapter.command, 'dap adapter ' .. adapter.name .. ' has no command')
  require_binary(adapter.command, 'dap adapter ' .. adapter.name)
end

local missing = {}
for binary, named_by in pairs(required) do
  if vim.fn.exepath(binary) == '' then
    table.insert(missing, binary .. ' (' .. table.concat(named_by, ', ') .. ')')
  end
end
table.sort(missing)

assert(#missing == 0, #missing .. ' tool(s) named by the config are not on '
  .. "Neovim's PATH -- add them to extraPackages in modules/neovim.nix, or stop "
  .. 'naming them:\n  ' .. table.concat(missing, '\n  '))

print(('external tools: ok (%d binaries, %d adapters)')
  :format(vim.tbl_count(required), #adapters))
