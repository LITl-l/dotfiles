-- Domain-specific configuration (WSL, SSH, local)
local platform = require 'platform'

local M = {}

function M.apply(config)
  -- Default shell configuration (platform-specific)
  if platform.is_windows then
    -- On Windows, prefer WSL2 and start in home directory
    config.default_prog = { 'wsl.exe', '--cd', '~' }
  elseif platform.is_linux then
    -- On Linux, use fish shell
    config.default_prog = { 'fish' }
  elseif platform.is_macos then
    -- On macOS, use fish shell from nix
    config.default_prog = { '/run/current-system/sw/bin/fish' }
  end

  -- Launch menu (platform-specific)
  config.launch_menu = {}

  if platform.is_windows then
    table.insert(config.launch_menu, {
      label = 'WSL2 (Home)',
      args = { 'wsl.exe', '--cd', '~' },
    })
    table.insert(config.launch_menu, {
      label = 'PowerShell',
      args = { 'powershell.exe', '-NoLogo' },
    })
    table.insert(config.launch_menu, {
      label = 'CMD',
      args = { 'cmd.exe' },
    })
  else
    table.insert(config.launch_menu, {
      label = 'Fish',
      args = { 'fish', '-l' },
    })
    table.insert(config.launch_menu, {
      label = 'Bash',
      args = { 'bash', '-l' },
    })
    table.insert(config.launch_menu, {
      label = 'Top',
      args = { 'top' },
    })
  end
end

return M
