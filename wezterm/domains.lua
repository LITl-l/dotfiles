-- Domain-specific configuration (WSL, SSH, local)
local platform = require 'platform'
local shell = require 'shell'

local M = {}

function M.apply(config)
  -- Default shell configuration (platform-specific)
  if platform.is_windows then
    -- On Windows, prefer WSL2 and start in home directory
    config.default_prog = { 'wsl.exe', '--cd', '~' }
  elseif platform.is_linux then
    -- On Linux, use fish shell from Nix
    config.default_prog = { shell.fish_path }
  elseif platform.is_macos then
    -- On macOS, use fish shell from Nix
    config.default_prog = { shell.fish_path }
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
      args = { shell.fish_path, '-l' },
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
