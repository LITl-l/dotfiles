-- Font configuration
local wezterm = require 'wezterm'
local platform = require 'platform'

local M = {}

function M.apply(config)
  -- Font family with fallbacks
  config.font = wezterm.font_with_fallback {
    'JetBrains Mono',
    'FiraCode Nerd Font',
    'Noto Color Emoji',
  }

  -- Platform-specific font sizes
  if platform.is_windows then
    config.font_size = 11.0
  elseif platform.is_macos then
    config.font_size = 13.0
  else -- Linux
    config.font_size = 11.0
  end

  config.line_height = 1.2
end

return M
