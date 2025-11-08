-- Mouse bindings configuration
local wezterm = require 'wezterm'

local M = {}

function M.apply(config)
  config.mouse_bindings = {
    -- Right click paste
    {
      event = { Up = { streak = 1, button = 'Right' } },
      mods = 'NONE',
      action = wezterm.action.PasteFrom 'Clipboard',
    },
    -- Change font size
    {
      event = { Down = { streak = 1, button = { WheelUp = 1 } } },
      mods = 'CTRL',
      action = wezterm.action.IncreaseFontSize,
    },
    {
      event = { Down = { streak = 1, button = { WheelDown = 1 } } },
      mods = 'CTRL',
      action = wezterm.action.DecreaseFontSize,
    },
  }
end

return M
