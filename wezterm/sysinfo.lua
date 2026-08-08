-- CPU / memory readout for the status bar.
--
-- Replaces tabline.wez's built-in `cpu` and `ram` components. Those run
-- `wmic cpu get loadpercentage` on Windows every 3 seconds, which measured
-- 1.3-5.4s per call here: Win32_Processor.LoadPercentage samples a performance
-- counter over a time window rather than reading one, so the sampler was busy
-- for most of the wall clock. It also failed open -- when the counter came back
-- empty, `string.format('%.2f%%', nil)` raised *before* the component updated
-- its throttle timestamp, so the throttle never engaged again and every
-- subsequent status update spawned another `wmic`.
--
-- The rules below fall out of that failure:
--
--   * The gate is claimed BEFORE sampling and re-armed after, so a throw or a
--     hang degrades to "the widget updates slowly", never to a spawn storm.
--   * Windows does the delta arithmetic inside one PowerShell invocation and
--     returns small integers. No 64-bit perf counter (Timestamp_Sys100NS is 18
--     digits) has to survive a round trip through Lua's number type, and a
--     failed sample cannot poison the next one via stale state.
--   * Linux reads /proc directly and spawns nothing at all, so it can afford a
--     much shorter interval than Windows.
--
-- Both platforms report memory as *used*, matching what Task Manager and
-- free(1) show. The upstream component reported free memory on Windows and
-- used memory on Linux under the same label.

local wezterm = require 'wezterm'
local platform = require 'platform'

local M = {}

-- Windows pays ~1.2s per sample (process spawn + WMI init + a 300ms counter
-- window), so 10s keeps the sampler under ~12% of the wall clock. Linux only
-- reads two files.
local INTERVAL = platform.is_windows and 10 or 3

-- If a sample throws or hangs, the gate stays this far out instead of the
-- normal interval. Long enough that a pathological sample can never queue up
-- behind itself, short enough to recover without a restart.
local STALL_GUARD = 120

local CPU_ICON = wezterm.nerdfonts.oct_cpu
local MEM_ICON = wezterm.nerdfonts.cod_server

local state = {
  next_at = 0,
  text = '',
  prev = nil, -- Linux only: cumulative jiffies from the previous sample
}

-- Two instant counter reads, 300ms apart, differenced in-process. Emits
-- tenths-of-a-percent plus memory in KB -- all small integers, so no locale
-- decimal separator and no precision cliff on the Lua side.
local POWERSHELL_SAMPLE = [[
$a = (Get-CimInstance Win32_PerfRawData_PerfOS_Processor | Where-Object Name -eq _Total)
Start-Sleep -Milliseconds 300
$b = (Get-CimInstance Win32_PerfRawData_PerfOS_Processor | Where-Object Name -eq _Total)
$di = $b.PercentIdleTime - $a.PercentIdleTime
$dt = $b.Timestamp_Sys100NS - $a.Timestamp_Sys100NS
if ($dt -le 0) { exit 1 }
$o = Get-CimInstance Win32_OperatingSystem
'{0} {1} {2}' -f [int][math]::Round(1000 - 1000 * $di / $dt), $o.TotalVisibleMemorySize, $o.FreePhysicalMemory
]]

local function clamp_percent(n)
  if n < 0 then return 0 end
  if n > 100 then return 100 end
  return n
end

local function render(cpu_percent, used_kb)
  return string.format(
    ' %s %.1f%%  %s %.1f GB ',
    CPU_ICON,
    clamp_percent(cpu_percent),
    MEM_ICON,
    used_kb / 1024 / 1024
  )
end

local function sample_windows()
  local ok, stdout = wezterm.run_child_process {
    'powershell.exe',
    '-NoProfile',
    '-NonInteractive',
    '-Command',
    POWERSHELL_SAMPLE,
  }
  if not ok or not stdout then
    return
  end

  local cpu_tenths, total_kb, free_kb = stdout:match('(%-?%d+)%s+(%d+)%s+(%d+)')
  cpu_tenths, total_kb, free_kb = tonumber(cpu_tenths), tonumber(total_kb), tonumber(free_kb)
  if not (cpu_tenths and total_kb and free_kb) or total_kb < free_kb then
    return
  end

  state.text = render(cpu_tenths / 10, total_kb - free_kb)
end

local function read_file(path)
  local handle = io.open(path, 'r')
  if not handle then
    return nil
  end
  local contents = handle:read('a')
  handle:close()
  return contents
end

-- /proc/stat's first line is cumulative jiffies since boot, so a percentage
-- only exists relative to a previous reading. `prev` is committed only when the
-- current reading parsed cleanly, otherwise the next sample would difference
-- against garbage and print a wildly wrong number.
local function sample_linux()
  local stat = read_file('/proc/stat')
  local meminfo = read_file('/proc/meminfo')
  if not (stat and meminfo) then
    return
  end

  local fields = {}
  for value in (stat:match('^cpu%s+([%d%s]+)') or ''):gmatch('%d+') do
    table.insert(fields, tonumber(value))
  end
  -- user nice system idle iowait irq softirq ... -- idle and iowait are both idle
  if #fields < 5 then
    return
  end

  local total, idle = 0, fields[4] + fields[5]
  for _, value in ipairs(fields) do
    total = total + value
  end

  local mem_total = tonumber(meminfo:match('MemTotal:%s+(%d+)'))
  local mem_available = tonumber(meminfo:match('MemAvailable:%s+(%d+)'))
  if not (mem_total and mem_available) or mem_total < mem_available then
    return
  end

  local previous = state.prev
  state.prev = { total = total, idle = idle }

  -- The first sample after startup has nothing to difference against.
  if not previous then
    return
  end
  local total_delta = total - previous.total
  local idle_delta = idle - previous.idle
  if total_delta <= 0 or idle_delta < 0 then
    return
  end

  state.text = render(100 - 100 * idle_delta / total_delta, mem_total - mem_available)
end

-- Returns the cached string immediately unless the interval has elapsed. Safe
-- to call from `update-status` as often as WezTerm likes.
function M.status()
  if os.time() < state.next_at then
    return state.text
  end

  -- Claim the gate before sampling. Nothing below re-arms it until a sampler
  -- has returned normally, so a throw or a hang leaves this longer gate in
  -- place rather than retrying at the normal cadence.
  state.next_at = os.time() + STALL_GUARD

  if platform.is_windows then
    sample_windows()
  elseif platform.is_linux then
    sample_linux()
  else
    -- macOS is deliberately unimplemented: there is no machine here to verify a
    -- vm_stat/sysctl path against, and an unverified sampler is exactly what
    -- caused the problem this module exists to fix. Leave the gate claimed.
    return state.text
  end

  -- Measured from completion, so a slow sample also spaces out the next one.
  state.next_at = os.time() + INTERVAL
  return state.text
end

return M
