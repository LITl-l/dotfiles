-- Pull in the wezterm API
local wezterm = require 'wezterm'

-- This table will hold the configuration.
local config = {}

-- In newer versions of wezterm, use the config_builder which will
-- help provide clearer error messages
if wezterm.config_builder then
  config = wezterm.config_builder()
end

-- Font configuration
config.font = wezterm.font 'Cica'
config.font_size = 12.0

-- Color scheme
config.color_scheme = 'Gruvbox Dark'

-- Keybindings
config.keys = {
  {
    key = 'C',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.CopyTo 'ClipboardAndPrimarySelection',
  },
  {
    key = 'V',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.PasteFrom 'Clipboard',
  },
}

-- For example, changing the look and feel of the tabs
config.use_fancy_tab_bar = false

-- and finally, return the configuration to wezterm
return config
