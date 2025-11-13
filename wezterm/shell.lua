-- Shell configuration with platform-specific paths
-- Note: This file can be overridden by Nix-generated version on NixOS
local M = {}

-- Detect fish shell path based on platform and available paths
local function detect_fish_path()
  local platform = require 'platform'

  if platform.is_windows then
    -- On Windows, fish is typically in WSL
    -- Default to 'fish' which will work in WSL environment
    return 'fish'
  elseif platform.is_linux then
    -- On Linux, try Nix path first, then fall back to PATH
    local nix_paths = {
      '/run/current-system/sw/bin/fish',
      '/nix/var/nix/profiles/default/bin/fish',
      os.getenv('HOME') .. '/.nix-profile/bin/fish',
    }

    for _, path in ipairs(nix_paths) do
      local f = io.open(path, 'r')
      if f then
        f:close()
        return path
      end
    end

    -- Fall back to system fish
    return 'fish'
  elseif platform.is_macos then
    -- On macOS, try Nix path first, then Homebrew, then fall back to PATH
    local paths = {
      '/run/current-system/sw/bin/fish',
      '/nix/var/nix/profiles/default/bin/fish',
      os.getenv('HOME') .. '/.nix-profile/bin/fish',
      '/opt/homebrew/bin/fish',
      '/usr/local/bin/fish',
    }

    for _, path in ipairs(paths) do
      local f = io.open(path, 'r')
      if f then
        f:close()
        return path
      end
    end

    -- Fall back to system fish
    return 'fish'
  end

  -- Default fallback
  return 'fish'
end

-- Fish shell path
M.fish_path = detect_fish_path()

return M
