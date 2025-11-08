-- Platform detection utilities
local wezterm = require 'wezterm'

local platform = {}

-- OS detection
platform.is_windows = wezterm.target_triple:find("windows") ~= nil
platform.is_linux = wezterm.target_triple:find("linux") ~= nil
platform.is_macos = wezterm.target_triple:find("darwin") ~= nil

return platform
