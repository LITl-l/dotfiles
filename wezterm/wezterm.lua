-- WezTerm configuration with modular structure
-- Each aspect of the configuration is separated into its own module for better organization
local wezterm = require 'wezterm'

-- Use the config builder if available
local config = {}
if wezterm.config_builder then
  config = wezterm.config_builder()
end

-- Load and apply all configuration modules
require('theme').apply(config)
require('fonts').apply(config)
require('appearance').apply(config)
require('keybindings').apply(config)
require('mouse').apply(config)
require('domains').apply(config)
require('performance').apply(config)

-- Load tabline plugin (must be loaded after other configurations)
require('tabline').apply(config)

return config
